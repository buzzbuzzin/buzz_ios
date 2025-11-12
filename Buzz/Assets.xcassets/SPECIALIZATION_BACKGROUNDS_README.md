# Specialization Background Images Guide

## Overview
Each specialization category has its own background image that appears behind the icon and text in the specialization cards.

## Image Sets Created
The following imagesets have been created in `Buzz/Assets.xcassets/`:

1. `Specialization_automotive_bg.imageset`
2. `Specialization_motion_picture_bg.imageset`
3. `Specialization_real_estate_bg.imageset`
4. `Specialization_agriculture_bg.imageset`
5. `Specialization_inspections_bg.imageset`
6. `Specialization_search_rescue_bg.imageset`
7. `Specialization_logistics_bg.imageset`
8. `Specialization_drone_art_bg.imageset`
9. `Specialization_surveillance_security_bg.imageset`

## How to Add Your Background Images

### Step 1: Prepare Your Images
For each specialization, you need background images in three sizes:

**Recommended Sizes:**
- For a card that's approximately 160x80 points in the UI:
  - `{specialization}_bg.png` - 160x80px (1x)
  - `{specialization}_bg@2x.png` - 320x160px (2x)
  - `{specialization}_bg@3x.png` - 480x240px (3x)

**Example for Automotive:**
- `automotive_bg.png` (160x80px)
- `automotive_bg@2x.png` (320x160px)
- `automotive_bg@3x.png` (480x240px)

### Step 2: Add Images to Xcode

**Option A: Using Finder**
1. Navigate to: `Buzz/Assets.xcassets/Specialization_{name}_bg.imageset/`
2. Copy your three PNG files into that folder
3. Make sure filenames match exactly (e.g., `automotive_bg.png`, `automotive_bg@2x.png`, `automotive_bg@3x.png`)

**Option B: Using Xcode**
1. Open Xcode
2. Navigate to `Buzz/Assets.xcassets` in Project Navigator
3. Click on the imageset (e.g., `Specialization_automotive_bg`)
4. Drag and drop your images into the 1x, 2x, and 3x slots
5. Or right-click the imageset → "Show in Finder" → Place files there

### Step 3: Update Contents.json (if needed)
If you use different filenames, update the `Contents.json` file in each imageset folder to match your filenames.

## Design Tips

1. **Contrast**: Since white text and icons appear on top, ensure your background images have good contrast. Darker backgrounds work best.

2. **Overlay**: The card automatically adds:
   - A dark overlay (20% black) when not selected for better text visibility
   - A blue overlay (40% blue) when selected to indicate selection

3. **Image Quality**: 
   - Use PNG format for best quality
   - Ensure images are high resolution (especially @3x)
   - Consider using images that work well when slightly darkened

4. **Aspect Ratio**: 
   - Cards are approximately 2:1 aspect ratio (width:height)
   - Images will be scaled to fill, so ensure important content is centered

5. **File Naming**: 
   - Follow the pattern: `{specialization_name}_bg.png`
   - Use underscores, not spaces or hyphens
   - Examples: `automotive_bg.png`, `motion_picture_bg.png`, `search_rescue_bg.png`

## Specialization Name Mapping

| Display Name | Imageset Name | Filename Pattern |
|-------------|---------------|------------------|
| Automotive | Specialization_automotive_bg | automotive_bg.png |
| Motion Picture | Specialization_motion_picture_bg | motion_picture_bg.png |
| Real Estate | Specialization_real_estate_bg | real_estate_bg.png |
| Agriculture | Specialization_agriculture_bg | agriculture_bg.png |
| Inspections | Specialization_inspections_bg | inspections_bg.png |
| Search & Rescue | Specialization_search_rescue_bg | search_rescue_bg.png |
| Logistics | Specialization_logistics_bg | logistics_bg.png |
| Drone Art | Specialization_drone_art_bg | drone_art_bg.png |
| Surveillance & Security | Specialization_surveillance_security_bg | surveillance_security_bg.png |

## Testing
After adding images:
1. Build and run the app
2. Navigate to Customer Sign Up → Page 3 (Specialization Selection)
3. Verify each specialization card displays its background image correctly
4. Check that text and icons remain readable over the backgrounds

## Fallback
If a background image is missing, the card will show a placeholder. Make sure all images are properly added to avoid missing assets.

