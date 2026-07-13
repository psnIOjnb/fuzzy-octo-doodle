// Generates brand PNG icons (no external deps) using zlib for PNG encoding.
// Icon: brass rounded square, dark inner card, three "subscription list" bars,
// with an accent "fuse" bar. Outputs base64 data URIs to stdout as JSON.
const zlib = require('zlib');

function hex(h){ h=h.replace('#',''); return [parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)]; }
const BRASS = hex('#E4B04A');
const BG    = hex('#14161F');
const CARD  = hex('#1D2029');
const DIM   = hex('#9BA0B0');
const WARN  = hex('#E4634A');

function makeIcon(size){
  const px = new Uint8Array(size*size*4); // RGBA, transparent
  const set=(x,y,[r,g,b],a=255)=>{ if(x<0||y<0||x>=size||y>=size)return; const i=(y*size+x)*4; px[i]=r;px[i+1]=g;px[i+2]=b;px[i+3]=a; };
  const rr=(x0,y0,w,h,rad,color)=>{ // filled rounded rect
    for(let y=0;y<h;y++)for(let x=0;x<w;x++){
      let inside=true;
      // corner rounding
      const cx = x<rad? rad-x-0.5 : (x>=w-rad? x-(w-rad)+0.5 : 0);
      const cy = y<rad? rad-y-0.5 : (y>=h-rad? y-(h-rad)+0.5 : 0);
      if(cx>0&&cy>0 && (cx*cx+cy*cy) > rad*rad) inside=false;
      if(inside) set(x0+x,y0+y,color,255);
    }
  };
  const s=size/1024; // scale factor from a 1024 design grid
  const S=(n)=>Math.round(n*s);
  // brass background tile
  rr(0,0,size,size,S(230),BRASS);
  // dark inner card
  rr(S(150),S(150),size-S(300),size-S(300),S(120),CARD);
  // three list bars
  const bx=S(255), bw=size-S(510), bh=S(74), gap=S(60);
  let by=S(300);
  const barColors=[DIM,DIM,DIM];
  for(let k=0;k<3;k++){ rr(bx,by,bw,bh,S(30),barColors[k]); by+=bh+gap; }
  // accent "fuse" progress bar (brass) with warn tip
  const fy=by+S(20);
  rr(bx,fy,bw,S(90),S(30),hex('#2E3342'));
  rr(bx,fy,Math.round(bw*0.62),S(90),S(30),BRASS);
  rr(bx+Math.round(bw*0.62)-S(90),fy,S(90),S(90),S(30),WARN);
  return px;
}

// minimal PNG encoder
function crc32(buf){ let c=~0; for(let i=0;i<buf.length;i++){ c^=buf[i]; for(let k=0;k<8;k++) c = (c>>>1) ^ (0xEDB88320 & -(c&1)); } return ~c>>>0; }
function chunk(type,data){ const t=Buffer.from(type,'ascii'); const len=Buffer.alloc(4); len.writeUInt32BE(data.length,0); const cd=Buffer.concat([t,data]); const crc=Buffer.alloc(4); crc.writeUInt32BE(crc32(cd),0); return Buffer.concat([len,cd,crc]); }
function encodePNG(px,size){
  const raw=Buffer.alloc((size*4+1)*size);
  for(let y=0;y<size;y++){ raw[y*(size*4+1)]=0; for(let x=0;x<size*4;x++) raw[y*(size*4+1)+1+x]=px[y*size*4+x]; }
  const ihdr=Buffer.alloc(13); ihdr.writeUInt32BE(size,0); ihdr.writeUInt32BE(size,4); ihdr[8]=8; ihdr[9]=6; ihdr[10]=0; ihdr[11]=0; ihdr[12]=0;
  const idat=zlib.deflateSync(raw,{level:9});
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]);
}

const out={};
for(const sz of [192,512]){ const p=encodePNG(makeIcon(sz),sz); out[sz]='data:image/png;base64,'+p.toString('base64'); }
process.stdout.write(JSON.stringify(out));
