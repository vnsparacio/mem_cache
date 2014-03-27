#!/usr/bin/env python
# DVI Display
# Author: David Schneider (dns@stanford.edu)
#
# Changes:
#   2012-02-07: Initial release
#
#

import gtk, gobject
import errno, os, subprocess, sys, time

# Limit the amount that can be read at once, so that we can simulate a
# simulation.  Setting to float('inf') will effectively remove the limit.
DBG_READ_LIMIT_B = float('inf')

# Since we're dealing with files over AFS, the times may not be perfectly
# synced.  Since simulations generally take a long time, adding a small fudge
# factor (in seconds) shouldn't cause mis-identifications of fresh images.
AFS_FUDGE_FACTOR_S = 5

# How frequently we poll the file or directory, in MS.
POLL_TIME_MS = 500

# The process we search for when no files or directories are provided on the
# command line. Passed into ps -C.
PROCESS_NAME = 'vvp'

# USAGE is printed if --help is passed or if there's no PROCESS_NAME running.
USAGE="""Usage: dvi-display.py [[directory | ppm_file] ... ]

DVI Display will monitor a PPM file and display the image frames within as they
are generated. If a directory is provided, the directory is watched for any PPM
file that is modified after DVI Display was launched, then switches to
displaying and monitoring that file as before. Multiple directories and/or PPM
files can be specified, and DVI Display will open each in individual windows.
If NO files or directories are specified, DVI Display will search for a process
named %s and start monitoring the process's working directory.
""" % PROCESS_NAME


# A list of all of the PpmDisplay instances.
# Once this list is empty, the program will quit.
ppm_displays = []

class PpmDisplay:
    """ The primary display class. Creates a GtkWindow and monitors the
    specified path (directory or file).
    """

    def __init__(self, path):
        """ Creates a new PpmDisplay that displays an image located at path.
        If path is a file, the file will be opened and displayed immediately.
        If path is a directory, wait for a ppm file that has a modified time
        greater than the time the class was created, then open and display that
        file.
        """
        # Store the current time, with a fudge factor for AFS time desync
        self.start_time = time.time() - AFS_FUDGE_FACTOR_S
        # Starting values
        self.path = path
        self.img_file = None
        self.img_bytes_remaining = 0
        self.pulse_timer = 0
        self.load_timer = 0
        self.loader = None
        self.pixbufs = []
        self.index = 0
        self.image_drag = False
        self.error_dialog = None
        self.error_text = None
        self.save_dialog = None
        # Create the UI and begin pulsing the progress bar
        self.initui()
        self.pulse()
        # Run self.load() later in the main loop, so that the window is visible
        gobject.idle_add(lambda: self.load() and False)

    def destroy(self, window):
        """ Destroyes the window and removes the PpmDisplay from the display
        list. If there are no displays remaining, exits the program.
        """
        self.cancel_pulse()
        # Cancel the poller
        if self.load_timer:
            gobject.source_remove(self.load_timer)
            self.load_timer = 0
        # Close any open image loaders. It may throw a GError if the file isn't
        # completely specified.
        if self.loader:
            try: self.loader.close()
            except gobject.GError: pass
            self.loader = None
        # Remove the display from the list and quit if nothing is left
        ppm_displays.remove(self)
        if not ppm_displays:
            gtk.main_quit()

    def initui(self):
        """ Create the window and all of the UI widgets, and make them visible.
        """
        ## Creating the objects
        # Create a window with custom accelerators
        accels = gtk.AccelGroup()
        self.window = gtk.Window()
        self.window.set_title('DVI Display: %s' % self.path)
        self.window.set_icon_name('display')
        self.window.connect('destroy', self.destroy)
        self.window.add_accel_group(accels)
        # Use a table for the main layout.
        # In it are rulers, a scrolling window for the image, and a toolbar.
        self.table = gtk.Table(rows=3, columns=2)
        self.hruler = gtk.HRuler()
        self.vruler = gtk.VRuler()
        self.scrollwindow = gtk.ScrolledWindow()
        self.scrollwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrollwindow.get_hadjustment().connect('value-changed',
                self.update_rulers)
        self.scrollwindow.get_vadjustment().connect('value-changed',
                self.update_rulers)
        self.scrollwindow.connect('size-allocate', self.update_rulers)
        # gtk.Image cannot scroll by itself, so we wrap it in a gtk.Viewport.
        self.imageviewport = gtk.Viewport()
        # Request mouse events
        self.imageviewport.add_events(gtk.gdk.POINTER_MOTION_MASK |
                                      gtk.gdk.BUTTON_PRESS_MASK |
                                      gtk.gdk.BUTTON_RELEASE_MASK)
        self.imageviewport.connect('motion-notify-event', self.image_mouse_move)
        self.imageviewport.connect('button-press-event',
                lambda w, event: self.image_mouse_button(event.button, True))
        self.imageviewport.connect('button-release-event',
                lambda w, event: self.image_mouse_button(event.button, False))
        self.imagedisplay = gtk.Image()
        self.imagedisplay.set_alignment(0, 0)
        # The toolbar is a simple H-box
        self.toolbar = gtk.HBox()
        # A button to display the mouse coordinates and copy them to clipboard
        self.coordinates = gtk.Button('')
        self.coordinates.get_child().set_markup(
                '<span face="mono"> %4s  %4s </span>' % ('', ''))
        self.coordinates.connect('clicked', self.coordinates_clicked)
        # Other toolbar widgets: previous, next, save, save all, progress
        self.prevbutton = gtk.Button(stock=gtk.STOCK_MEDIA_PREVIOUS)
        self.prevbutton.connect('clicked',
                lambda b: self.display_image(self.index - 1))
        self.nextbutton = gtk.Button(stock=gtk.STOCK_MEDIA_NEXT)
        self.nextbutton.connect('clicked',
                lambda b: self.display_image(self.index + 1))
        self.savebutton = gtk.Button(stock=gtk.STOCK_SAVE)
        self.savebutton.connect('clicked', lambda b: self.save_image(False))
        self.saveallbutton = gtk.Button("Save _All")
        self.saveallbutton.set_image(
                gtk.image_new_from_stock(gtk.STOCK_SAVE, gtk.ICON_SIZE_BUTTON))
        self.saveallbutton.connect('clicked', lambda b: self.save_image(True))
        self.progress = gtk.ProgressBar()

        # Update the toolbar, setting sensitivities and text
        self.update_bar()

        ## Defining extra accelerators
        self.nextbutton.add_accelerator('clicked', accels, ord('n'), 0, 0)
        self.nextbutton.add_accelerator('clicked', accels, ord('j'), 0, 0)
        self.nextbutton.add_accelerator('clicked', accels, ord('l'), 0, 0)
        self.nextbutton.add_accelerator('clicked', accels, ord('.'), 0, 0)
        self.nextbutton.add_accelerator('clicked', accels, ord('>'), 0, 0)
        self.prevbutton.add_accelerator('clicked', accels, ord('p'), 0, 0)
        self.prevbutton.add_accelerator('clicked', accels, ord('k'), 0, 0)
        self.prevbutton.add_accelerator('clicked', accels, ord('h'), 0, 0)
        self.prevbutton.add_accelerator('clicked', accels, ord(','), 0, 0)
        self.prevbutton.add_accelerator('clicked', accels, ord('<'), 0, 0)
        self.savebutton.add_accelerator('clicked', accels,
                                        ord('s'), gtk.gdk.CONTROL_MASK, 0)
        self.coordinates.add_accelerator('clicked', accels,
                                         ord('c'), gtk.gdk.CONTROL_MASK, 0)

        ## Making the widget hierarchy
        self.imageviewport.add(self.imagedisplay)
        self.scrollwindow.add(self.imageviewport)
        self.table.attach(self.hruler, 1, 2, 0, 1,
                          xoptions=gtk.FILL, yoptions=gtk.FILL)
        self.table.attach(self.vruler, 0, 1, 1, 2,
                          xoptions=gtk.FILL, yoptions=gtk.FILL)
        self.table.attach(self.scrollwindow, 1, 2, 1, 2)

        self.toolbar.pack_start(self.prevbutton, expand=False)
        self.toolbar.pack_start(self.coordinates, expand=False)
        self.toolbar.pack_start(self.progress)
        self.toolbar.pack_start(self.saveallbutton, expand=False)
        self.toolbar.pack_start(self.savebutton, expand=False)
        self.toolbar.pack_start(self.nextbutton, expand=False)
        self.table.attach(self.toolbar, 0, 2, 2, 3, yoptions=gtk.FILL)

        self.window.add(self.table)
        ## Show everything
        self.window.show_all()

    def image_mouse_button(self, button, pressed):
        """ Callback when a button is pressed or released.
        """
        # Keep track of our state, and return True if the event is drag-related
        if button == 1:
            self.image_drag = pressed
            return True
        return self.image_drag

    def image_mouse_move(self, widget, event):
        """ Callback when the mouse is moved.
        """
        # Update the ruler marker and coordinates text
        self.hruler.set_property('position', event.x)
        self.vruler.set_property('position', event.y)
        self.coordinates.get_child().set_markup_with_mnemonic(
                '<span face="mono"> %4i_, %4i </span>' % (event.x, event.y))
        return True

    def coordinates_clicked(self, button):
        """ Callback when the coordinates button is clicked.
        """
        # Get rid of the extra spaces and save the coordinates to the clipboard.
        gtk.Clipboard().set_text(
                ' '.join(button.get_child().get_text().split()))

    def update_rulers(self, widget=None, rectangle=None):
        """ Updates the range of the rulers to match the scroll of the image.
        """
        x = self.scrollwindow.get_hadjustment().get_value()
        y = self.scrollwindow.get_vadjustment().get_value()
        if not rectangle:
            rectangle = self.scrollwindow.get_allocation()
        self.hruler.set_property('lower', x)
        self.vruler.set_property('lower', y)
        self.hruler.set_property('upper', rectangle.width + x)
        self.vruler.set_property('upper', rectangle.height + y)

    def pixbufloader_area_prepared(self, pixbufloader):
        """ Callback when the size of the image is now known, and loading can
        begin.
        """
        self.cancel_pulse()
        self.progress.set_fraction(0)
        # The pixbuf in the loader is now valid. Construct our own pixbuf for
        # display using the size. We start the pixbuf off as just a checkerboard
        # pattern (overall_alpha = 0) and load in the actual content in
        # pixbufloader_area_updated as it is made available.
        pixbuf = pixbufloader.get_pixbuf()
        pixbuf = pixbuf.composite_color_simple(
                    pixbuf.get_width(), pixbuf.get_height(),
                    gtk.gdk.INTERP_NEAREST, overall_alpha=0,
                    check_size=32, color1=0xAAAAAA, color2=0x555555)
        # If this is our first pixbuf, update the rulers' max-size property (a
        # hint to the ruler the maximum number it will show, so that it can
        # space things properly), as well as the window size.
        if not self.pixbufs:
            self.hruler.set_property('max-size', pixbuf.get_width())
            self.vruler.set_property('max-size', pixbuf.get_height())
            # Figure out the target window size by taking the difference between
            # the current viewport size and the window size, and assuming the
            # scroll bars will be shown once we have an image.
            scrollwindow_size = self.scrollwindow.get_allocation()
            scroll_size = (self.scrollwindow.get_vscrollbar().size_request()[0],
                           self.scrollwindow.get_hscrollbar().size_request()[1])
            viewport_size = (scrollwindow_size.width - scroll_size[0] - 2,
                             scrollwindow_size.height - scroll_size[1] - 2)
            window_size = self.window.get_size()
            # Use set_default_size and reshow_with_initial_size so that the
            # window manager can prevent the window from becoming bigger than
            # the screen.
            self.window.set_default_size(
                    pixbuf.get_width()  + window_size[0] - viewport_size[0],
                    pixbuf.get_height() + window_size[1] - viewport_size[1])
            self.window.reshow_with_initial_size()
        # Add the new pixbuf to the list, and display it if the index is set
        # such that we were waiting for it.
        self.pixbufs.append(pixbuf)
        if self.index == len(self.pixbufs) - 1:
            self.display_image()
        else:
            # self.display_image calls self.update_bar, so we need to do it
            # ourselves if we don't call display_image.
            self.update_bar()

    def pixbufloader_area_updated(self, pixbufloader, x, y, width, height):
        """ Callback when a new row of the image is available to be displayed.
        """
        pixbuf = pixbufloader.get_pixbuf()
        size = pixbuf.get_width() * pixbuf.get_height()
        self.progress.set_fraction(float(y*pixbuf.get_width() + x + width)/size)
        # Copy the new area to our display pixbuf
        pixbuf.copy_area(x, y, width, height, self.pixbufs[-1], x, y)
        # If we are displaying this image, we need to trigger a redraw of the
        # new area.
        if self.index == len(self.pixbufs) - 1:
            self.imagedisplay.queue_draw_area(x, y, width, height)

    def save_image(self, save_all):
        """ Saves the current image (or all images) to a file.
        This function does everything up to the save dialog.
        """
        # But don's do anything if we have no images or are already trying to
        # save.
        if not self.pixbufs or self.save_dialog:
            return
        # Don't allow two presses
        self.savebutton.set_sensitive(False)
        self.saveallbutton.set_sensitive(False)
        # Handle save_all
        if not save_all:
            pixbuf = self.pixbufs[self.index]
            title='Save frame %i from %s' % (self.index+1, self.path)
        else:
            pixbuf = None
            title='Save all frames from %s' % self.path
        # Create the save dialog
        self.save_dialog = gtk.FileChooserDialog(title=title,
                parent=self.window, action=gtk.FILE_CHOOSER_ACTION_SAVE,
                buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
                         gtk.STOCK_SAVE, gtk.RESPONSE_ACCEPT))
        # Associate the chosen pixbuf (if not save_all) with the save dialog
        self.save_dialog.set_data('pixbuf', pixbuf)
        # Only allow selection of PNG images
        filefilter = gtk.FileFilter()
        filefilter.add_pattern('*.png')
        filefilter.set_name('PNG Images')
        self.save_dialog.add_filter(filefilter)
        self.save_dialog.set_filter(filefilter)
        # Display the save dialog, and expect a response
        self.save_dialog.connect('response', self.save_response)
        self.save_dialog.show()

    def save_response(self, dialog, response_id):
        """ Callback when the save dialog is responded to. The save dialog is
        still visible.
        """
        # Keep track of the response to the "overwrite" dialog (assume OK if it
        # wasn't even displayed, or the save dialog itself was cancelled)
        response = gtk.RESPONSE_OK
        # If the user didn't cancel the save dialog:
        if response_id == gtk.RESPONSE_ACCEPT:
            pixbuf = self.save_dialog.get_data('pixbuf')
            # Make sure the filename ends in .png
            filename = self.save_dialog.get_filename()
            split = list(os.path.splitext(filename))
            if split[1].lower() != '.png':
                split[0] += split[1]
                split[1] = '.png'
            # Create the list of filenames and pixbufs
            if not pixbuf is None:
                filenames = [''.join(split)]
                pixbufs = [pixbuf]
            else:
                # Remove trailing _1 if it exists
                if split[0].endswith('_1'):
                    split[0] = split[0][:-2]
                # Resulting pattern: filename_i.png
                filenames = ['%s_%i%s' % (split[0], i+1, split[1])
                             for i in range(len(self.pixbufs))]
                pixbufs = self.pixbufs
            # Check for files that already exist
            conflicts = []
            for f in filenames:
                if os.path.exists(f):
                    conflicts.append(f)
            # If files exist, show the overwrite dialog
            if conflicts:
                dialog = gtk.MessageDialog(self.save_dialog,
                    gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                    gtk.MESSAGE_WARNING, gtk.BUTTONS_OK_CANCEL,
                    'The following files already exist.\n' +
                    'Are you sure you want to overwrite them?')
                dialog.set_title('Overwrite Confirmation')
                dialog.set_icon_name('warning')
                dialog.format_secondary_text('\n'.join(conflicts))
                response = dialog.run()
                dialog.destroy()
            # If we didn't cancel the overwrite dialog, save the images
            if response == gtk.RESPONSE_OK:
                for pixbuf, filename in zip(pixbufs, filenames):
                    pixbuf.save(filename, 'png')
        # If the save dialog should be dismissed (save dialog cancelled, or
        # overwrite NOT cancelled), destroy it.
        if response == gtk.RESPONSE_OK:
            self.savebutton.set_sensitive(True)
            self.saveallbutton.set_sensitive(True)
            self.save_dialog.destroy()
            self.save_dialog = None

    def display_image(self, index=None):
        """ Display the selected image.  If index is not provided, the currently
        selected image (self.index) is (re-)displayed.
        """
        if not index is None:
            self.index = max(min(index, len(self.pixbufs) - 1), 0)
        self.imagedisplay.set_from_pixbuf(self.pixbufs[self.index])
        self.update_bar()

    def update_bar(self):
        """ Update the toolbar, setting text and button sensitivities.
        """
        # Don't enable the toolbar at all if we have no images
        self.toolbar.set_sensitive(len(self.pixbufs) != 0)
        # Enable the previous and next buttons if we can actually move in that
        # direction
        self.prevbutton.set_sensitive(self.index > 0)
        self.nextbutton.set_sensitive(self.index < len(self.pixbufs) - 1)
        # Update the progress text
        self.progress.set_text('Displaying %i of %i' %
                               (self.index+1, len(self.pixbufs)))

    def pulse(self):
        """ Start/continue pulsing the progress bar.
        """
        if not self.pulse_timer:
            self.pulse_timer = gobject.timeout_add(100, self.pulse)
        self.progress.pulse()
        return True

    def cancel_pulse(self):
        """ Stop pulsing the progress bar, if it is pulsing.
        """
        if self.pulse_timer:
            gobject.source_remove(self.pulse_timer)
            self.pulse_timer = 0

    def error_response(self, dialog, response_id):
        """ Callback for the response to the "cannot be found" error dialog.
        """
        # Destroy the window if we chose not to continue searching.
        if response_id == gtk.RESPONSE_CANCEL:
            self.window.destroy()
        self.error_dialog.destroy()
        self.error_dialog = None

    def error_display(self, errortext):
        """ Displays an error dialog about the current file that is trying to
        be opened.  Error text is the extra info on why the file was unable to
        be opened.  If the user hits "cancel", the program will quit.
        """
        # Only open the dialog for a unique error.
        if self.error_text != errortext:
            # If we did have a dialog, but it was different, destroy it.
            if self.error_dialog: self.error_dialog.destroy()
            # Save the text for checking later.
            self.error_text = errortext
            self.error_dialog = gtk.MessageDialog(self.window,
                gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                gtk.MESSAGE_ERROR, gtk.BUTTONS_OK_CANCEL,
                'Cannot access %s (%s)\nClick OK to continue trying.' %
                    (self.path, errortext))
            self.error_dialog.set_title('DVI Display Error (%s)' %
                                            self.path)
            self.error_dialog.set_icon_name('error')
            self.error_dialog.connect('response', self.error_response)
            self.error_dialog.show()

    def load(self):
        """ Start/contiune loading the display dump.  Called periodically.
        If we only have a directory, search the directory.  If we have a file,
        load as much of the file as possible.
        Returns True to continue being periodically run.
        """
        # Start the timer if necessary.
        if not self.load_timer:
            self.load_timer = gobject.timeout_add(POLL_TIME_MS, self.load)
        # If we haven't opened the image file yet
        if not self.img_file:
            if os.path.isdir(self.path):
                # Search the provided directories for files of extension PPM
                # that were modified after we were launched.
                for f in os.listdir(self.path):
                    full_path = os.path.join(self.path, f)
                    if (os.path.isfile(full_path) and
                            os.path.splitext(f)[1].lower() == '.ppm' and
                            os.path.getmtime(full_path) >= self.start_time):
                        # Keep the first file we see.
                        self.path = full_path
                        break
                else:
                    # Only return if we couldn't find a file.
                    return True
            elif not os.path.exists(self.path):
                # The file doesn't exist!
                self.error_display('file not found')
                return True

            # Try to open the file. If we still can't for some reason, that's
            # okay, return and try again.
            try:
                self.img_file = open(self.path, 'rb')
            except IOError, e:
                if e.errno == errno.EACCES:
                    self.error_display('access denied')
                return True

            # Successfully opened the file. Destroy the error dialog.
            if self.error_dialog:
                self.error_dialog.destroy()
                self.error_dialog = None

        # If we are done with a frame / about to start a new one
        if not self.img_bytes_remaining:
            # Grab the first line of the file (if we're not at EOF)
            line = self.img_file.readline()
            if not len(line):
                return True
            # There's some data, so an image will probably follow.
            # Start pulsing the progress bar.
            self.pulse()
            # Busy-loop as we try to grab the rest of the line.  Since the
            # simulation prints out the entire first line at once, this really
            # shouldn't be an issue.
            while line[-1] != '\n':
                line += self.img_file.readline()
            # Split into fields. A PPM file goes like this:
            #     magic width height max_pixel_value data
            # For simplicity we assume the header is a single line, but in
            # reality, any amount of whitespace (including newlines) can
            # separate the different header entries.
            width, height, maxval = [int(x) for x in line.split()[1:4]]
            # PPMs will either be two bytes per color value or one
            if maxval >= 256: bytesperpixel = 2*3
            else:             bytesperpixel = 1*3
            # Figure out how much data we need for this image
            self.img_bytes_remaining = width * height * bytesperpixel
            # Start loading the image by passing the header information to the
            # loader.
            self.loader = gtk.gdk.PixbufLoader('pnm')
            self.loader.connect('area-prepared',
                                self.pixbufloader_area_prepared)
            self.loader.connect('area-updated', self.pixbufloader_area_updated)
            self.loader.write(line)

        # If we've started loading a file, pass new data to it
        if self.loader:
            # Don't load more data than we have remaining in the image, so that
            # we can manually process the next image header. Also don't pass
            # more than DBG_READ_LIMIT_B so that we can artificially
            # slow loading down for testing.
            data = self.img_file.read(min(self.img_bytes_remaining,
                                          DBG_READ_LIMIT_B))
            if len(data):
                self.img_bytes_remaining -= len(data)
                self.loader.write(data)
            # If we're done loading, close the loader.
            if not self.img_bytes_remaining:
                self.loader.close()
                self.loader = None
        # Keep periodically calling this function.
        return True

def getPids():
    """ Searches for a process named PROCESS_NAME, and returns the matching
    pids. Accomplished through a call to "ps"
    """
    return subprocess.Popen(['ps', '-opid=', '-C' + PROCESS_NAME],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE).communicate()[0].split()

if __name__ == '__main__':
    """ Main function when called as a script.
    Checks the command line parameters and instantiates PpmDisplays as
    appropriate.
    """
    # If paths were provided
    if len(sys.argv) > 1:
        # Was it help? Just display USAGE.
        if sys.argv[1] == '-h' or sys.argv[1] == '--help':
            sys.stderr.write(USAGE)
            sys.exit(0)
        # Otherwise, create a PpmDisplay for each path.
        for path in sys.argv[1:]:
            # If the path consists of just "." or "..", expand it.
            splitpath = path.split('/')
            if splitpath.count('.') + splitpath.count('..') == len(splitpath):
                path = os.path.abspath(path)
            ppm_displays.append(PpmDisplay(path))
    else:
        # No paths were provided, so search for the PROCESS_NAME process.
        sys.stderr.write('No paths provided; checking for iverilog instances\n')
        paths = []
        for pid in getPids():
            # Get the actual path of each process's current working directory.
            # This might fail due to permissions errors.
            try:
                path = os.path.realpath(os.path.join('/proc', pid, 'cwd'))
            except OSError: continue
            # Do a quick superficial check to see if we can access the
            # directory, although AFS permissions may thwart this later.
            if os.access(path, os.R_OK | os.W_OK):
                sys.stderr.write('Found iverilog pid %s, directory "%s"' % (
                                     pid, path))
                # Avoid redundant paths
                if path not in paths:
                    # Path isn't redundant! Create a PpmDisplay
                    sys.stderr.write('\n')
                    paths.append(path)
                    ppm_displays.append(PpmDisplay(path))
                else:
                    sys.stderr.write(' (redundant)\n')
        if not ppm_displays:
            # No pids found. Display USAGE.
            sys.stderr.write('No iverilog instances found\n')
            sys.stderr.write(USAGE)
            sys.exit(1)
    # GTK main loop. Everything happens here.
    try: gtk.main()
    except KeyboardInterrupt: pass
