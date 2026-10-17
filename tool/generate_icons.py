"""Regenerate original launcher artwork (requires Pillow, build-time only)."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
root = Path(__file__).resolve().parents[1]
size=1024
im=Image.new('RGB',(size,size),'#4ECDC4'); d=ImageDraw.Draw(im)
d.rounded_rectangle((170,280,854,790),radius=116,fill='#F4FAF8')
d.rounded_rectangle((190,302,834,770),radius=96,outline='#14211F',width=32)
d.rounded_rectangle((598,448,858,632),radius=52,fill='#D6F5EF',outline='#14211F',width=28)
d.ellipse((655,516,699,560),fill='#14211F')
d.ellipse((349,116,675,442),fill='#FFA568',outline='#14211F',width=28)
d.line((512,193,512,364),fill='#14211F',width=25)
d.arc((449,197,575,284),110,280,fill='#14211F',width=22)
d.arc((449,275,575,360),290,100,fill='#14211F',width=22)
im.save(root/'assets/branding/app-icon.png')
for folder,s in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 im.resize((s,s),Image.Resampling.LANCZOS).save(root/f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png')
p=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'; content=json.loads((p/'Contents.json').read_text())
for item in content['images']:
 if 'filename' in item:
  s=round(float(item['size'].split('x')[0])*float(item['scale'].rstrip('x')))
  im.resize((s,s),Image.Resampling.LANCZOS).save(p/item['filename'])
