#!/usr/bin/env python3
"""Validate or bump SemVer without committing, tagging or publishing."""
import pathlib,re,argparse
root=pathlib.Path(__file__).resolve().parent.parent
pattern=r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
def validate(value):
 if not re.fullmatch(pattern,value):raise ValueError('Expected Semantic Versioning, such as 0.2.0 or 0.3.0-beta.1')
 return value
def main():
 parser=argparse.ArgumentParser();parser.add_argument('bump',nargs='?',choices=['major','minor','patch']);parser.add_argument('--set');args=parser.parse_args()
 current=validate((root/'VERSION').read_text().strip())
 if args.bump or args.set:
  if args.set:updated=validate(args.set)
  else:
   major,minor,patch=map(int,current.split('-')[0].split('+')[0].split('.'))
   updated={'major':f'{major+1}.0.0','minor':f'{major}.{minor+1}.0','patch':f'{major}.{minor}.{patch+1}'}[args.bump]
  (root/'VERSION').write_text(updated+'\n');(root/'BUILD_NUMBER').write_text(str(int((root/'BUILD_NUMBER').read_text())+1)+'\n');current=updated
 print(current)
if __name__=='__main__':main()
