# Pilot Icon

## How to Add Your Pilot Icon

1. **Prepare Your Icon Files:**
   - For best quality, export your icon in three sizes:
     - `PilotIcon.png` - 1x size (e.g., 24x24px for a small icon)
     - `PilotIcon@2x.png` - 2x size (e.g., 48x48px)
     - `PilotIcon@3x.png` - 3x size (e.g., 72x72px)

2. **Recommended Sizes for Small UI Icons:**
   - If you want a 24pt icon in the UI:
     - PilotIcon.png: 24x24px (1x)
     - PilotIcon@2x.png: 48x48px (2x)
     - PilotIcon@3x.png: 72x72px (3x)

3. **Add Files:**
   - Drag and drop your PNG files into this folder (`PilotIcon.imageset/`)
   - OR in Xcode: Right-click `PilotIcon.imageset` → "Show in Finder" → Place files there
   - Make sure the filenames match exactly: `PilotIcon.png`, `PilotIcon@2x.png`, `PilotIcon@3x.png`

4. **Usage in Code:**
   ```swift
   // Basic usage
   Image("PilotIcon")
       .resizable()
       .scaledToFit()
       .frame(width: 24, height: 24)
   
   // As a small icon in a button
   Image("PilotIcon")
       .resizable()
       .scaledToFit()
       .frame(width: 20, height: 20)
   
   // With tint color (if icon supports it)
   Image("PilotIcon")
       .resizable()
       .renderingMode(.template)
       .foregroundColor(.blue)
       .frame(width: 24, height: 24)
   ```

## Alternative: Single Image
If you only have one high-resolution icon:
- Use your PNG file and rename it to `PilotIcon@3x.png`
- Copy it to all three slots (or just use @3x, Xcode will scale it down)
- Update Contents.json to reference the same file for all scales

## Tips
- Use PNG format with transparency for best results
- Keep the icon simple and recognizable at small sizes
- Test the icon at different sizes to ensure it looks good
- Consider using SF Symbols for system consistency, but custom icons work great for branding

