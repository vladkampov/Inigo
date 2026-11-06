#!/usr/bin/env python3
"""Reviewable repository setup. Default is dry-run; never creates public content."""
import argparse,json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--apply',action='store_true')
parser.add_argument('--create-private',action='store_true')
args=parser.parse_args()
repo='vladkampov/Inigo'
commands=[]
if args.create_private:commands.append(['gh','repo','create',repo,'--private','--description','Private, native macOS writing refinement and translation.'])
commands.append(['gh','repo','edit',repo,'--enable-issues','--enable-wiki=false','--delete-branch-on-merge','--enable-squash-merge','--enable-merge-commit=false','--enable-rebase-merge=false','--add-topic','macos','--add-topic','swift','--add-topic','local-ai','--add-topic','translation'])
for label in json.loads((root/'.github/labels.json').read_text()):
 commands.append(['gh','label','create',label['name'],'--repo',repo,'--color',label['color'],'--description',label['description'],'--force'])

for command in commands:
 print(' '.join(command))
 if args.apply:subprocess.run(command,check=True)
print('Enable private vulnerability reporting after the repository is public (GitHub does not support it on private repositories).')
print('Next: push reviewed source; configure branch rules, Pages and the protected release environment. Public visibility is a separate decision.')
