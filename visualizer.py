import time
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import serial

# --- CONFIGURATION ---
SERIAL_PORT = 'COM5'     # Change to your port (e.g., 'COM3' on Windows or '/dev/ttyUSB0' on Linux/Mac)
BAUD_RATE = 10417         # Match your COM module baud rate (9600)
WINDOW_SIZE = 200        # Number of samples to display on screen at once
Y_MIN = 0                # Minimum ADC value (0)
Y_MAX = 255              # Maximum ADC value (255 for 8-bit ADRESH)

# --- SERIAL CONNECTION ---
try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)
    print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
except Exception as e:
    print(f"Error opening serial port {SERIAL_PORT}: {e}")
    exit(1)

# Buffer for plotted values
data_buffer = [0] * WINDOW_SIZE

# --- PLOT SETUP ---
fig, ax = plt.subplots()
line, = ax.plot(data_buffer, color='b', lw=1.5)
ax.set_ylim(Y_MIN - 5, Y_MAX + 5)
ax.set_xlim(0, WINDOW_SIZE - 1)
ax.set_title("PIC16F887 ADC Real-Time Serial Plotter")
ax.set_xlabel("Sample")
ax.set_ylabel("ADC Value (0-255)")
ax.grid(True)

def update(frame):
    global data_buffer
    
    # Read all available bytes from serial buffer
    if ser.in_waiting > 0:
        raw_bytes = ser.read(ser.in_waiting)
        
        # Treat each incoming raw byte as a sample (0-255)
        new_values = [b for b in raw_bytes]
        
        # Append new values and maintain fixed window size
        data_buffer.extend(new_values)
        data_buffer = data_buffer[-WINDOW_SIZE:]
        
        # Update plot data
        line.set_ydata(data_buffer)
        
    return line,

# Animate plot every 20ms
ani = animation.FuncAnimation(fig, update, interval=20, blit=True)

try:
    plt.show()
finally:
    ser.close()
    print("Serial port closed.")
