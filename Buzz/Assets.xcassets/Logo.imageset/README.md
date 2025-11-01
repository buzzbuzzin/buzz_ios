# Company Logo

## How to Add Your Logo

1. **Prepare Your Logo Files:**
   - Export your logo in three sizes:
     - `Logo.png` - 1x size (for non-Retina displays)
     - `Logo@2x.png` - 2x size (double resolution)
     - `Logo@3x.png` - 3x size (triple resolution for Plus/Pro Max devices)

2. **Recommended Sizes:**
   - If your logo is 200x200px at 1x:
     - Logo.png: 200x200px
     - Logo@2x.png: 400x400px
     - Logo@3x.png: 600x600px

3. **Add Files:**
   - Drag and drop the three logo files into this folder (`Logo.imageset/`)
   - OR in Xcode: Right-click `Logo.imageset` → "Show in Finder" → Place files there

4. **Usage in Code:**
   ```swift
   Image("Logo")
       .resizable()
       .scaledToFit()
       .frame(width: 100, height: 100)
   ```

## Alternative: Single Image
If you only have one high-resolution logo:
- Use `Logo@3x.png` for all three slots
- Xcode will automatically scale it down for other sizes

## Tips
- Use PNG format for best quality
- Keep background transparent if logo should blend with app design
- For simple logos, consider using SF Symbols or SVG (if supported)

