import gi
from pathlib import Path
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
window=Gtk.Window(title="Fourier GTK target");window.set_default_size(640,240)
text=Gtk.TextView();buffer=text.get_buffer()
def changed(buf):
    Path("/tmp/tap-inserted.txt").write_text(buf.get_text(buf.get_start_iter(),buf.get_end_iter(),True))
buffer.connect("changed",changed);window.add(text);window.show_all();text.grab_focus();Gtk.main()
