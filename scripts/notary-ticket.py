#!/usr/bin/env python3
"""Retry only observed transient Apple ticket-service failures; never skip validation."""
import subprocess,sys,time
def main():
 if len(sys.argv)!=3 or sys.argv[1] not in ('staple','validate'):raise SystemExit('Usage: notary-ticket.py staple|validate APP')
 for attempt in range(4):
  result=subprocess.run(['xcrun','stapler',sys.argv[1],sys.argv[2]],capture_output=True,text=True)
  print(result.stdout,end='');print(result.stderr,end='',file=sys.stderr)
  if result.returncode==0:return
  if result.returncode!=68 or 'Code=-1005' not in result.stdout+result.stderr or attempt==3:raise SystemExit(result.returncode)
  print('Apple ticket connection lost; retrying the same verification.',flush=True);time.sleep(10*(attempt+1))
if __name__=='__main__':main()
