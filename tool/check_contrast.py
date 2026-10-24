#!/usr/bin/env python3
"""Fails the build if any Cove token pair misses its WCAG 2.2 AA floor.
Text >= 4.5:1 on every surface it can land on. Non-text marks >= 3:1."""
import json,sys,pathlib
d=json.load(open(pathlib.Path(__file__).parent.parent/'design/tokens.json'))
def rgb(h):
    h=h.lstrip('#')
    if len(h)==8: return tuple(int(h[i:i+2],16) for i in (0,2,4))+(int(h[6:8],16)/255,)
    return tuple(int(h[i:i+2],16) for i in (0,2,4))+(1.0,)
def lum(c):
    f=lambda v:(v/255)/12.92 if v/255<=0.03928 else (((v/255)+0.055)/1.055)**2.4
    return .2126*f(c[0])+.7152*f(c[1])+.0722*f(c[2])
def cr(a,b):
    L1,L2=sorted((lum(a),lum(b)),reverse=True); return (L1+.05)/(L2+.05)
def val(g,n,m):
    v=d[g][n]['$value']; return v[m] if isinstance(v,dict) and m in v else v
TEXT=[('text','primary'),('text','secondary'),('text','tertiary'),('accent','text'),
      ('status','alertText'),('money','more'),('money','less'),('status','good')]
MARK=[('accent','fill'),('status','alert')]
fails=[]
for mode in ('dark','light'):
    surfaces={k:rgb(val('surface',k,mode)) for k in ('canvas','card','row')}
    for g,n in TEXT:
        for sn,sv in surfaces.items():
            r=cr(rgb(val(g,n,mode)),sv)
            if r<4.5: fails.append(f"{mode}: {g}.{n} on surface.{sn} = {r:.2f} (need 4.5)")
    for g,n in MARK:
        for sn,sv in surfaces.items():
            r=cr(rgb(val(g,n,mode)),sv)
            if r<3.0: fails.append(f"{mode}: {g}.{n} on surface.{sn} = {r:.2f} (need 3.0)")
    r=cr(rgb(val('text','onAccent',mode)),rgb(val('accent','fill',mode)))
    if r<4.5: fails.append(f"{mode}: text.onAccent on accent.fill = {r:.2f}")
    for k in d['category']:
        r=cr(rgb(val('category',k,mode)),rgb(val('surface','canvas',mode)))
        if r<3.0: fails.append(f"{mode}: category.{k} = {r:.2f} (need 3.0)")
paper_stops={k:rgb(val('paper',k,'light')) for k in ('from','via','to')}
PAPER_TEXT=[('paper','ink'),('paper','ink2'),('paper','ink3'),('paper','accent')]
PAPER_MARK=[('paper','accent'),('status','good'),('paper','ink3')]+[('category',k) for k in d['category']]
for g,n in PAPER_TEXT:
    for sn,sv in paper_stops.items():
        r=cr(rgb(val(g,n,'light')),sv)
        if r<4.5: fails.append(f"paper: {g}.{n} on paper.{sn} = {r:.2f} (need 4.5)")
for g,n in PAPER_MARK:
    for sn,sv in paper_stops.items():
        r=cr(rgb(val(g,n,'light')),sv)
        if r<3.0: fails.append(f"paper: {g}.{n} on paper.{sn} = {r:.2f} (need 3.0)")
ink_stops={k:rgb(val('slip',k,'dark')) for k in ('inkFrom','inkVia','inkTo')}
INK_TEXT=[('text','primary'),('text','secondary'),('accent','text'),
          ('money','more'),('money','less'),('slip','inkText3'),('slip','inkAlertText')]
INK_MARK=[('accent','fill'),('slip','inkMark')]
for g,n in INK_TEXT:
    for sn,sv in ink_stops.items():
        r=cr(rgb(val(g,n,'dark')),sv)
        if r<4.5: fails.append(f"ink: {g}.{n} on slip.{sn} = {r:.2f} (need 4.5)")
for g,n in INK_MARK:
    for sn,sv in ink_stops.items():
        r=cr(rgb(val(g,n,'dark')),sv)
        if r<3.0: fails.append(f"ink: {g}.{n} on slip.{sn} = {r:.2f} (need 3.0)")
def mix(a,b,t): return tuple(round(a[i]+(b[i]-a[i])*t) for i in range(3))+(1.0,)
for p,l in (('a','aLabel'),('b','bLabel')):
    g=d['person'][p]['$value']; lab=rgb(d['person'][l]['$value'])
    f,t=rgb(g['from']),rgb(g['to'])
    worst=min(cr(lab,mix(f,t,x/100)) for x in range(101))
    if worst<4.5: fails.append(f"person.{p} initial across its gradient = {worst:.2f} (need 4.5)")
# person.both is unfilled: its ampersand is text.primary on a surface, already covered above
if fails:
    print("CONTRAST GATE FAILED\n"+"\n".join("  ! "+f for f in fails)); sys.exit(1)
print("contrast gate: all pairs pass")
