import tkinter as tk
import math
import platform
import sys

# Platform-specific imports for click-through functionality
if platform.system() == 'Darwin':  # macOS
    try:
        import ctypes
        import ctypes.util
        
        # Load Cocoa framework
        objc = ctypes.cdll.LoadLibrary(ctypes.util.find_library('objc'))
        
        objc.objc_getClass.restype = ctypes.c_void_p
        objc.sel_registerName.restype = ctypes.c_void_p
        
        # Simple wrapper for objc_msgSend  
        def objc_msg(obj, selector):
            """Send message with no extra arguments"""
            objc.objc_msgSend.restype = ctypes.c_void_p
            objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
            return objc.objc_msgSend(obj, objc.sel_registerName(selector.encode()))
        
        def objc_msg_long(obj, selector):
            """Send message that returns a long"""
            objc.objc_msgSend.restype = ctypes.c_long
            objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
            return objc.objc_msgSend(obj, objc.sel_registerName(selector.encode()))
        
        def objc_msg_index(obj, selector, index):
            """Send message with an integer argument"""
            objc.objc_msgSend.restype = ctypes.c_void_p
            objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long]
            return objc.objc_msgSend(obj, objc.sel_registerName(selector.encode()), index)
        
        def objc_msg_bool(obj, selector, value):
            """Send message with a boolean argument"""
            objc.objc_msgSend.restype = None
            objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_bool]
            objc.objc_msgSend(obj, objc.sel_registerName(selector.encode()), value)
        
        def make_clickthrough(window_id):
            """Make a Tkinter window click-through on macOS"""
            try:
                # Get NSApplication shared instance
                NSApp = objc_msg(objc.objc_getClass(b'NSApplication'), 'sharedApplication')
                
                # Get all windows
                windows = objc_msg(NSApp, 'windows')
                window_count = objc_msg_long(windows, 'count')
                
                print(f"Found {window_count} window(s)")
                sys.stdout.flush()
                
                if window_count > 0:
                    # Get the first window
                    nswindow = objc_msg_index(windows, 'objectAtIndex:', 0)
                    
                    # Set window to ignore mouse events (click-through)
                    objc_msg_bool(nswindow, 'setIgnoresMouseEvents:', True)
                    
                    print("✓ Click-through enabled successfully")
                    sys.stdout.flush()
                    return True
                else:
                    print("No windows found to make click-through")
                    sys.stdout.flush()
                    return False
            except Exception as e:
                print(f"Warning: Could not enable click-through: {e}")
                import traceback
                traceback.print_exc()
                sys.stdout.flush()
                return False
    except ImportError:
        print("Warning: ctypes not available, click-through disabled")
        def make_clickthrough(window_id):
            return False
elif platform.system() == 'Windows':
    try:
        import ctypes
        from ctypes import wintypes
        
        def make_clickthrough(window_id):
            """Make a Tkinter window click-through on Windows"""
            try:
                # Get window handle
                hwnd = ctypes.windll.user32.GetParent(window_id)
                
                # Get extended window styles
                GWL_EXSTYLE = -20
                WS_EX_LAYERED = 0x00080000
                WS_EX_TRANSPARENT = 0x00000020
                
                # Get current style
                style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
                
                # Add layered and transparent flags
                style = style | WS_EX_LAYERED | WS_EX_TRANSPARENT
                
                # Set new style
                ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)
                
                return True
            except Exception as e:
                print(f"Warning: Could not enable click-through: {e}")
                return False
    except ImportError:
        print("Warning: ctypes not available, click-through disabled")
        def make_clickthrough(window_id):
            return False
else:
    # Linux/Other - not implemented
    def make_clickthrough(window_id):
        print("Click-through not implemented for this platform")
        return False

class ProjectileOverlay:
    def __init__(self, root):
        self.root = root
        self.root.title("Wind Physics Overlay")
        
        # Remove window decorations (frameless/borderless)
        self.root.overrideredirect(True)
        
        # OS-Specific Transparency Setup
        current_os = platform.system()
        
        if current_os == 'Windows':
            self.bg_color = 'grey15'
            self.root.attributes('-transparentcolor', self.bg_color)
            self.root.configure(bg=self.bg_color)
            canvas_bg = self.bg_color
            # Enable click-through on Windows
            self.root.attributes('-topmost', True)
            
        elif current_os == 'Darwin':  # macOS
            # macOS requires 'systemTransparent' background and -transparent attribute
            self.root.attributes('-transparent', True)
            self.root.config(bg='systemTransparent')
            canvas_bg = 'systemTransparent'
            # Keep window on top
            self.root.attributes('-topmost', True)
            
        else: # Linux/Other (Fallback to simple alpha)
            self.root.attributes('-alpha', 0.7)
            self.root.configure(bg='grey')
            canvas_bg = 'grey'
            self.root.attributes('-topmost', True)

        # Get screen dimensions and make fullscreen
        w, h = root.winfo_screenwidth(), root.winfo_screenheight()
        root.geometry(f"{w}x{h}+0+0")

        # Canvas for drawing the projectile path/dot
        # highlightthickness=0 removes the border that might show up
        self.canvas = tk.Canvas(root, bg=canvas_bg, highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # UI Control Frame (Opaque so you can see it)
        # We put this in a container that prevents it from becoming transparent on some systems
        self.controls = tk.Frame(root, bg='#2b2b2b', padx=10, pady=10)
        self.controls.place(x=20, y=20)

        # Inputs
        self.create_input("Wind Speed (0-12):", "wind_speed", 0)
        self.create_input("Wind Angle (0-360):", "wind_angle", 0) # 0 is Right, 90 is Up
        self.create_input("Shot Power (0-400):", "power", 200)
        self.create_input("Shot Angle (0-90):", "angle", 45)
        
        # Origin Point (Where the tank is) - draggable
        self.origin_x = 300
        self.origin_y = 600
        self.origin_dot = self.canvas.create_oval(
            self.origin_x-5, self.origin_y-5, self.origin_x+5, self.origin_y+5, 
            fill='blue', outline='white', tags="origin"
        )
        self.canvas.tag_bind("origin", "<B1-Motion>", self.move_origin)
        
        # Calculate Button
        btn = tk.Button(self.controls, text="Calculate & Draw", 
                       command=self.calculate_trajectory, 
                       bg='#4CAF50', fg='white', font=('Arial', 10, 'bold'),
                       relief=tk.FLAT, padx=10, pady=5)
        btn.pack(pady=5, fill=tk.X)
        
        # Quit Button (since we removed window decorations)
        quit_btn = tk.Button(self.controls, text="Quit (ESC)", 
                            command=self.root.quit, 
                            bg='#ff4444', fg='white', font=('Arial', 10, 'bold'),
                            relief=tk.FLAT, padx=10, pady=5)
        quit_btn.pack(pady=5, fill=tk.X)
        
        # Keyboard shortcut to quit
        self.root.bind('<Escape>', lambda e: self.root.quit())

        self.inputs = {}

    def create_input(self, label_text, key, default_val):
        frame = tk.Frame(self.controls, bg='#2b2b2b')
        frame.pack(fill=tk.X, pady=2)
        lbl = tk.Label(frame, text=label_text, width=20, anchor='w', 
                      bg='#2b2b2b', fg='#ffffff', font=('Arial', 10))
        lbl.pack(side=tk.LEFT)
        entry = tk.Entry(frame, width=10, bg='#3c3c3c', fg='#ffffff', 
                        insertbackground='#ffffff', relief=tk.FLAT, 
                        font=('Arial', 10))
        entry.insert(0, str(default_val))
        entry.pack(side=tk.RIGHT)
        
        if not hasattr(self, 'input_widgets'):
            self.input_widgets = {}
        self.input_widgets[key] = entry

    def move_origin(self, event):
        self.origin_x = event.x
        self.origin_y = event.y
        self.canvas.coords("origin", event.x-5, event.y-5, event.x+5, event.y+5)
        self.calculate_trajectory()

    def calculate_trajectory(self):
        self.canvas.delete("prediction")

        try:
            v0 = float(self.input_widgets['power'].get())
            theta = math.radians(float(self.input_widgets['angle'].get()))
            wind_s = float(self.input_widgets['wind_speed'].get())
            wind_a = math.radians(float(self.input_widgets['wind_angle'].get()))
        except ValueError:
            return

        # Physics Constants (Adjust these for calibration)
        GRAVITY = 9.8 
        WIND_FACTOR = 0.5 
        TIME_STEP = 0.1
        MAX_TIME = 10.0 

        t = 0
        points = []
        
        while t < MAX_TIME:
            # Wind Decomposition
            wx = wind_s * math.cos(wind_a) * WIND_FACTOR
            wy = wind_s * math.sin(wind_a) * WIND_FACTOR 
            
            # Trajectory math
            dx = (v0 * math.cos(theta) * t) + (wx * t)
            dy = (v0 * math.sin(theta) * t) - (0.5 * GRAVITY * t**2) + (wy * t)
            
            screen_x = self.origin_x + dx
            screen_y = self.origin_y - dy 
            
            points.append((screen_x, screen_y))
            
            if screen_y > self.root.winfo_height():
                break
                
            t += TIME_STEP

        for px, py in points:
             self.canvas.create_oval(px-2, py-2, px+2, py+2, fill='red', outline='', tags="prediction")

if __name__ == "__main__":
    root = tk.Tk()
    app = ProjectileOverlay(root)
    
    # Enable click-through after window is created
    # Need to process events first to ensure window is fully initialized
    root.update_idletasks()
    root.after(100, lambda: make_clickthrough(root.winfo_id()))
    
    root.mainloop()

