# Anamorphic-desqueeze
This is a very early version
Desqueeze your DNGs for easier edditing, it was built in godot and uses both [Exiftool](https://github.com/exiftool/exiftool) for desqueezing and [Adobe DNG converter](https://helpx.adobe.com/camera-raw/desktop/dng-and-file-formats/adobe-dng-converter.html) to convert Canon CR3 files into DNGs before desqueezing them. This tool currently only works on windows.

# Dependencies
- Requires Adobe DNG Converter installed at it's default location, get it [here](https://helpx.adobe.com/camera-raw/desktop/dng-and-file-formats/adobe-dng-converter.html)
- [Exiftool](https://github.com/exiftool/exiftool) is bundled in the tools folder
- DNG or CR3 raw files

# How to use
- Add your DNG or CR3 files to the queue by selecting "Add Files" (Please note that "Add Folder" isn't currently supported).
- Enter the squeeze factor of your lens
- Choose to desqueeze horizontally or vertically
- Click "Start" to start processing the files

Under the list of files a status label and progress bar should inform you of the conversion progress or potential errors.
The desqueezed DNGs should appear in next to your original files with the "_desqueezed" suffix.
I have only tested this method by imported the DNGs into lightroom and RapidRaw, please note that in lightroom for some reason you need to view the images in the Develop tab for the desqueeze to take effect.

# Current plans for improvement
- Add better error reporting
- Add support for adding folders
- Completely rework the UI, the current is only a functional POC
- Add support for Linux and maybe MacOS
- Add individual progress bars for files
- Find a workaround for Adobe DNG Converter CLI refusing place the converted files into a seperate folder
- Maybe support more RAW image formats

Any support is welcome!
