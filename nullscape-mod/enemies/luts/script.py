import os
import argparse
from PIL import Image

def process_images(image_path, max_strength, total_steps, output_folder="output_levels"):
    # 1. Validate Input
    if not os.path.exists(image_path):
        print(f"Error: The file '{image_path}' was not found.")
        return

    # 2. Create Output Directory
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        print(f"Created output directory: {output_folder}")

    try:
        # Load the original image
        original_img = Image.open(image_path)
        if original_img.mode != 'RGB':
            original_img = original_img.convert('RGB')
            
        filename = os.path.basename(image_path)
        name, ext = os.path.splitext(filename)

        print(f"Processing: {filename}")
        print(f"Max Black Point Strength: {max_strength}/255")
        print("-" * 30)

        for i in range(1, total_steps + 1):
            # Calculate progress t from 0.0 to 1.0
            if total_steps > 1:
                t = (i - 1) / (total_steps - 1)
            else:
                t = 0

            # Calculate the 'Black Point' for this step
            # 0 = No change (Normal)
            # max_strength = The darkest pixels are turned to pure black
            current_black_point = int(t * max_strength)

            # --- Define the Levels Function ---
            # This creates a Lookup Table (LUT) to map pixels.
            # Formula: NewVal = (OldVal - BlackPoint) * 255 / (255 - BlackPoint)
            # This clips values below the black point to 0 and stretches the rest.
            def level_map(p):
                if p < current_black_point:
                    return 0
                if current_black_point >= 255: # Avoid division by zero
                    return 0
                return int((p - current_black_point) * 255 / (255 - current_black_point))

            # Apply the mapping to every pixel in the image
            # point() is very fast compared to looping over pixels manually
            final_img = original_img.point(level_map)

            # Save the image
            output_filename = f"{name}_{i:02d}{ext}"
            output_path = os.path.join(output_folder, output_filename)
            
            final_img.save(output_path)
            
            # Progress bar
            print(f"[{i}/{total_steps}] Saved {output_filename} (Black Point: {current_black_point})")

        print("-" * 30)
        print(f"Done! Saved to '{output_folder}'")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate 50 images with progressively crushed blacks (levels adjustment).")
    
    parser.add_argument("image_path", help="Path to the input image file")
    
    # New argument for max strength
    parser.add_argument("--max", type=int, default=120, 
                        help="The intensity of the final effect (0-255). "
                             "Low (e.g., 50) = subtle darkening. "
                             "High (e.g., 150) = deep contrast/silhouette. "
                             "Default is 120.")

    # New argument for max strength
    parser.add_argument("--steps", type=int, default=50, 
                        help="The amount of images that will be generated "
                             "Default is 50.")
    
    args = parser.parse_args()
    
    # Validation to ensure max is within bounds
    if args.max < 0 or args.max > 255:
        print("Error: --max must be between 0 and 255.")
    elif args.steps <= 1 or args.steps > 255:
        print("Error: --steps must be between 2 and 255.")
    else:
        process_images(args.image_path, args.max, args.steps)
