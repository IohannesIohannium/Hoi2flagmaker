# HoI2 flag maker

This repository has a batch file and some powershell scripts that will create the various HoI2 files needed to have a flag work in game.

ImageMagick is required.

The output files will be organized in subfolders in output that can be pasted as-is into the HoI2 mod.

## Usage

You have an input folder subfolder, where you will put the bmp flag file, with the name of the tag. You can use a bmp supporting transparency and it will work (though if the shape is not rectangular, some green pixels may creep in due to pre-multiplication). Input flags should strive to be in a 3:2 ratio. Since in HoI2 one's interaction with countries is either warfare or diplomacy, the state flag should be preferred, rather than the civil flag.

### Shields

HoI2 shields_xxx.bmp files use vertical flags. The rules on how to turn a flag vertical are not widely agreed upon and, in fact, except for a dozen of countries explicitly signaling what to do, the lazy workaround is to simply rotated the flag 90 degrees clockwise. In reality, turning a flag vertical requires to distinguish the geometric partitions of the background and the emblems: geometric partitions will get transformed as (x,y)->(y,x), whereas elements will only have their position thus changed, but are meant to stand upright. Since, however, sometimes this may need resizing -- plus the fact that some flags are actually banners of arms, so the background is to be stretched, not rotated -- there are two possible ways to signal the changes needed to turn a flag vertical: either xxx_emblems.bmp (a transparent-background bmp with only the elements that need to stay upright while the emblems-free background, saved in xxx.bmp, is stretched) or xxx_vertical.bmp (the vertical flag, also in 3:2 ratio). The elements position is calculated on their mathematical center, which may however cause them to slightly drift.

### Counters
In the input subfolder, the file colours.csv is present, with four columns. Creating counters will have the program check if the tag has an entry in that file and use the RGB value written there for the base of the counter; if no value could be found, it will default to feldgrau.

The airforce subfolder contains the airforce emblems to be pasted onto the counters. They are also bmp files with transparency. If no airforce emblem is found for a tag, the flag will simply get pasted again.

### GIF
Although not part of HoI2, the program will be able to convert the generated wavying flag sprites into gif files with transparency. If any flag ever needs to be shown to be waved with the hoist on its right (as in the case for the Sahrawi Republic claiming Western Sahara), one should use the obverse in the input flag file, launch the program, reverse the generated flag sprite, and only after it has been reversed saying yes to the batch file prompting the generation of gif flags.

## Other content
Currently, the input and output subfolders are populated by all countries and dependencies currently exstant in the world with a valid passport code -- as well as a couple exceptional entries that are either valid for passports or are agreed upon in international databases --, all with their passport code used as tag, plus Akrotiri and Dhekelia, Mount Athos and Transnistria. For colours, if a HoI2 vanilla tag could not be found matching a current country, the colour was taken from the Toast3r colour scheme.

## Code quality
This has been vibe-coded with AI. It is clear that it could be optimized, but I don't know powershell enough to be able to do so.
