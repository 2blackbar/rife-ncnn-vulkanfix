0<0# : ^
''' 
@echo off
set script=%~f0
python -x "%script%" %*
exit /b 0
'''
import tkinter as tk
from tkinter import Entry, font, filedialog
import subprocess
import os
from PIL import Image
import shutil
import  re
from datetime import datetime

root = tk.Tk()
root.title("RIFE-NCNN-VULKAN GUI")

default_font = font.nametofont("TkDefaultFont")
default_font.configure(size=int(default_font['size'] * 1.5))
entry_font = font.Font(size=12, weight='bold')

# Function to remove label after some time
def remove_label(label):
    label.destroy()

# Function to resize images
def resize_clicked():
    input_path = input_path_entry.get()
    output_path = output_path_entry.get()

    if os.path.isdir(input_path) and os.path.isdir(output_path):
        files = os.listdir(input_path)
        first_image = None

        for filename in files:
            if filename.endswith((".png", ".jpg", ".jpeg", ".gif", ".bmp")):
                filepath = os.path.join(input_path, filename)
                image = Image.open(filepath)

                if first_image is None:
                    first_image = image
                    first_size = image.size
                else:
                    image = image.resize(first_size)
                    image.save(filepath)

        success_label = tk.Label(root, text="All images resized to the same size as the first image.",
                                 font=("Helvetica", 12, "bold"), fg="red")
        success_label.grid(row=4, column=0, columnspan=2)
        root.after(2000, lambda: remove_label(success_label))
    else:
        error_label = tk.Label(root, text="Invalid input or output path. Enter valid directories.",
                               font=("Helvetica", 12, "bold"), fg="red")
        error_label.grid(row=4, column=0, columnspan=2)
        root.after(2000, lambda: remove_label(error_label))

# Function to move files from 'out' to 'in'
def move_out_to_in():
    input_path = input_path_entry.get()
    output_path = output_path_entry.get()

    files_to_move = [filename for filename in os.listdir(output_path) if filename.endswith(".png")]

    if files_to_move:
        remove_files_from_directory(input_path)

        moved_files = []
        for filename in files_to_move:
            shutil.move(os.path.join(output_path, filename), os.path.join(input_path, filename))
            moved_files.append(filename)

        if moved_files:
            success_label = tk.Label(root, text="Moved output files to input folder", font=("Helvetica", 12, "bold"), fg="red")
            success_label.grid(row=4, column=0, columnspan=2)
            root.after(2000, lambda: remove_label(success_label))
    else:
        error_label = tk.Label(root, text="No PNG files found in the 'out' directory.",
                               font=("Helvetica", 12, "bold"), fg="red")
        error_label.grid(row=4, column=0, columnspan=2)
        root.after(2000, lambda: remove_label(error_label))


# Function to run ffmpeg
def run_ffmpeg():
    command = ['ffmpeg', '-framerate', '30', '-i', 'out/%08d.png', '-c:v', 'libx265', '-crf', '10', '-pix_fmt',
               'yuv444p', 'out/output.mp4']
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, error = process.communicate()

    if error:
        print(f'Error: {error.decode()}')
    else:
        print(f'Output: {output.decode()}')

# Function to remove files from a directory
def remove_files_from_directory(directory):
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)
        if os.path.isfile(file_path):
            os.remove(file_path)

# Function to convert images to jpg
def convert_images_to_jpg(directory):
    for filename in os.listdir(directory):
        if filename.endswith(".png"):
            filepath = os.path.join(directory, filename)
            image = Image.open(filepath)
            image = image.convert("RGB")
            new_filepath = os.path.splitext(filepath)[0] + ".tga"
            image.save(new_filepath, format="TGA")

    for filename in os.listdir(directory):
        if filename.endswith(".tga"):
            filepath = os.path.join(directory, filename)
            image = Image.open(filepath)
            new_filepath = os.path.splitext(filepath)[0] + ".png"
            image.save(new_filepath, format="PNG")
            os.remove(filepath)

# Function to browse input folder
def browse_input_folder():
    input_folder = filedialog.askdirectory()
    input_path_entry.delete(0, tk.END)
    input_path_entry.insert(0, input_folder)

# Function to browse output folder
def browse_output_folder():
    output_folder = filedialog.askdirectory()
    output_path_entry.delete(0, tk.END)
    output_path_entry.insert(0, output_folder)

# Function to generate command
def generate_command():
    command = "rife-ncnn-vulkan.exe"
    input_path = input_path_entry.get()

    if input_path:
        command += f' -i "{input_path}"'

    output_path = output_path_entry.get()

    if output_path:
        command += f' -o "{output_path}"'

    num_inbetween_frames = num_frame_entry.get()

    if num_inbetween_frames:
        num_input_frames = len([name for name in os.listdir(input_path) if os.path.isfile(os.path.join(input_path, name))])
        target_frame_count = num_input_frames + (int(num_inbetween_frames) * (num_input_frames - 1))
        command += f" -n {target_frame_count}"

    time_step = time_step_entry.get()
    if time_step:
        command += f" -s {time_step}"  # Include the time step in the command

    model_name = model_name_var.get()

    if model_name:
        command += f" -m {model_name}"

    if spatial_tta_var.get():
        command += " -x"

    if temporal_tta_var.get():
        command += " -z"

    if uhd_var.get():
        command += " -u"

    remove_files_from_directory(output_path)

    input_path = input_path_entry.get()

    if convert_images_var.get() and input_path:
        convert_images_to_jpg(input_path)

    command_output_label["text"] = command
    print(command)
    subprocess.run(command)
    run_ffmpeg()



def remove_label(label):
    label.grid_forget()
    
    
def convert_to_gif():
    try:
        # Define the path to the ffmpeg executable
        ffmpeg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg.exe")

        # Define the directory containing the images
        image_dir = output_path_entry.get()  # Use the output path as the input path

        # Generate a list of all .png files in the directory
        image_files = [f for f in os.listdir(image_dir) if f.endswith(".png")]

        # Sort the list of image files
        image_files.sort()

        # Create a temporary directory
        temp_dir = os.path.join(image_dir, "temp")
        os.makedirs(temp_dir, exist_ok=True)

        # Copy the image files to the temporary directory with a new naming pattern
        for i, image_file in enumerate(image_files):
            shutil.copy(os.path.join(image_dir, image_file), os.path.join(temp_dir, f"frame{i:04d}.png"))

        # Get the current date and time
        now = datetime.now()
        timestamp = now.strftime("%Y%m%d_%H%M%S")

        # Define the output GIF file path with the current date and time
        gif_path = os.path.join(image_dir, f"output_{timestamp}.gif")

        # Define the palette path
        palette_path = os.path.join(image_dir, "palette.png")

        # Generate color palette from the first image
        palette_command = f'"{ffmpeg_path}" -i "{os.path.join(temp_dir, "frame0000.png")}" -vf palettegen -y "{palette_path}"'
        subprocess.run(palette_command, shell=True)

        # Get the GIF framerate from the entry
        gif_framerate = gif_framerate_entry.get()

        # Use the generated palette for creating the GIF without dithering
        gif_command = f'"{ffmpeg_path}" -framerate {gif_framerate} -i "{os.path.join(temp_dir, "frame%04d.png")}" -i "{palette_path}" -filter_complex "[0:v][1:v]paletteuse=dither=none" -y "{gif_path}"'
        subprocess.run(gif_command, shell=True)

        # Remove the palette file
        os.remove(palette_path)

        # Remove the temporary directory
        shutil.rmtree(temp_dir)

    except Exception as e:
        print(f"Error converting to GIF: {e}")


def convert_to_mp4():
    try:
        # Define the path to the ffmpeg executable
        ffmpeg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg.exe")

        framerate = gif_framerate_entry.get()
        # Define the directory containing the images
        image_dir = output_path_entry.get()  # Use the output path as the input path

        # Generate a list of all .png files in the directory
        image_files = [f for f in os.listdir(image_dir) if f.endswith(".png")]

        # Sort the list of image files
        image_files.sort()

        # Create a temporary directory
        temp_dir = os.path.join(image_dir, "temp")
        os.makedirs(temp_dir, exist_ok=True)

        # Copy the image files to the temporary directory with a new naming pattern
        for i, image_file in enumerate(image_files):
            shutil.copy(os.path.join(image_dir, image_file), os.path.join(temp_dir, f"frame{i:04d}.png"))

        # Get the current date and time
        now = datetime.now()
        timestamp = now.strftime("%Y%m%d_%H%M%S")

        # Define the output MP4 file path with the current date and time
        mp4_path = os.path.join(image_dir, f"output_{timestamp}.mp4")

        # Convert the PNG sequence to an MP4 with a CRF of 10
        mp4_command = f'"{ffmpeg_path}" -framerate {framerate} -i "{os.path.join(temp_dir, "frame%04d.png")}" -c:v libx264 -crf 10 "{mp4_path}"'
        subprocess.run(mp4_command, shell=True)

        # Remove the temporary directory
        shutil.rmtree(temp_dir)

    except Exception as e:
        print(f"Error converting to MP4: {e}")
        
        
resize_button = tk.Button(root, text="Resize all input Images to match first image", command=resize_clicked)
resize_button.grid(row=5, column=0, columnspan=2, pady=(10, 0))

move_files_button = tk.Button(root, text="Move output Files to input folder", command=move_out_to_in)
move_files_button.grid(row=6, column=0, columnspan=2, pady=(10, 0))

# Add a new button for GIF conversion
convert_button = tk.Button(root, text="Output frames to GIF", command=convert_to_gif, fg="red", font=("Helvetica", 12, "bold"))
convert_button.grid(row=13, column=0, columnspan=2, pady=(10, 0))

# Add a new button for MP4 conversion
convert_button = tk.Button(root, text="Output frames to MP4", command=convert_to_mp4, fg="red", font=("Helvetica", 12, "bold"))
convert_button.grid(row=14, column=0, columnspan=2, pady=(10, 0))

# Widgets and layout adjustments
tk.Label(root, text="Input folder Path:").grid(row=0, column=0, sticky="E")
input_path_entry = tk.Entry(root, font=entry_font)
input_path_entry.insert(0, "in")
input_path_entry.grid(row=0, column=1, sticky="EW")

browse_input_button = tk.Button(root, text="Browse", command=browse_input_folder)
browse_input_button.grid(row=0, column=2, sticky="W", padx=(10, 0))

tk.Label(root, text="Output folder Path:").grid(row=1, column=0, sticky="E")
output_path_entry = tk.Entry(root, font=entry_font)
output_path_entry.insert(0, "out")
output_path_entry.grid(row=1, column=1, sticky="EW")

browse_output_button = tk.Button(root, text="Browse", command=browse_output_folder)
browse_output_button.grid(row=1, column=2, sticky="W", padx=(10, 0))

tk.Label(root, text="INTERPOLATE BY and TIMESTEP (only rife4 and higher):",
         fg="red", font=("Helvetica", 12, "bold")).grid(row=2, columnspan=3)


num_frame_entry = tk.Entry(root, font=entry_font)
num_frame_entry.insert(0, "4")
num_frame_entry.grid(row=3, columnspan=3)

time_step_entry = tk.Entry(root, font=entry_font)
time_step_entry.insert(0, "0.5")
time_step_entry.grid(row=4, columnspan=3)

tk.Label(root, text="GIF/MP4 FPS:").grid(row=12, column=0, sticky="E") 
gif_framerate_entry = tk.Entry(root, font=entry_font)
gif_framerate_entry.insert(0, "30")  # Set a default value
gif_framerate_entry.grid(row=12, column=1, sticky="EW")


model_frame = tk.Frame(root)
model_frame.grid(row=0, column=3, rowspan=12, sticky=tk.N, padx=(0, 10))

tk.Label(model_frame, text="Model Name:").pack(pady=(0, 10))

current_directory = os.path.dirname(os.path.realpath(__file__))
entries = os.listdir(current_directory)

model_name_var = tk.StringVar(value="rife-v4.6")
model_names = [entry for entry in entries if os.path.isdir(os.path.join(current_directory, entry)) and entry.startswith('rife')]
radio_buttons = []

for i, model_name in enumerate(model_names):
    button = tk.Radiobutton(
        model_frame,
        text=model_name,
        variable=model_name_var,
        value=model_name,
    )
    button.pack(anchor=tk.W)
    radio_buttons.append(button)

spatial_tta_var = tk.BooleanVar()
spatial_tta_checkbutton = tk.Checkbutton(
    root,
    text="Enable Spatial TTA Mode",
    variable=spatial_tta_var,
    onvalue=True,
    offvalue=False
)
spatial_tta_checkbutton.grid(row=7, columnspan=2)

temporal_tta_var = tk.BooleanVar()
temporal_tta_checkbutton = tk.Checkbutton(
    root,
    text="Enable Temporal TTA Mode",
    variable=temporal_tta_var,
    onvalue=True,
    offvalue=False
)
temporal_tta_checkbutton.grid(row=8, columnspan=2)

uhd_var = tk.BooleanVar()
uhd_checkbutton = tk.Checkbutton(
    root,
    text="Enable UHD Mode",
    variable=uhd_var,
    onvalue=True,
    offvalue=False
)
uhd_checkbutton.grid(row=9, columnspan=2)

convert_images_var = tk.BooleanVar()
convert_images_checkbutton = tk.Checkbutton(
    root,
    text="Convert Input Images to PNG",
    variable=convert_images_var,
    onvalue=True,
    offvalue=False
)
convert_images_checkbutton.grid(row=10, columnspan=2)

generate_command_button = tk.Button(
    root,
    text="INTERPOLATE",
    command=generate_command,
    fg="red",
    font=("Helvetica", 12, "bold")
)
generate_command_button.grid(row=11, columnspan=2)

 


command_output_label = tk.Label(root, text="", font=("Helvetica", 12))
command_output_label.grid(row=18, columnspan=2)

root.mainloop()
