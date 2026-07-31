import{r as p,j as n,m as v}from"./index-CTbCzCAe.js";const j=`
@keyframes holo-shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
@keyframes holo-pulse {
  0%, 100% { opacity: 0.3; }
  50% { opacity: 0.6; }
}
.holo-glare {
  background: linear-gradient(
    105deg,
    transparent 20%,
    rgba(255,255,255,0.03) 30%,
    rgba(255,255,255,0.12) 38%,
    rgba(255,255,255,0.03) 46%,
    transparent 56%,
    transparent 100%
  );
  background-size: 200% 100%;
  animation: holo-shimmer 4s ease-in-out infinite;
}
.holo-rainbow {
  background: linear-gradient(
    120deg,
    rgba(255,0,0,0.06) 0%,
    rgba(255,154,0,0.06) 12%,
    rgba(208,222,33,0.06) 24%,
    rgba(79,220,74,0.06) 36%,
    rgba(63,218,216,0.06) 48%,
    rgba(47,201,226,0.06) 60%,
    rgba(28,127,238,0.06) 72%,
    rgba(95,21,242,0.06) 84%,
    rgba(186,12,248,0.06) 100%
  );
  background-size: 300% 300%;
  animation: holo-shimmer 6s ease infinite;
}
`;if(typeof document<"u"&&!document.getElementById("holo-styles")){const e=document.createElement("style");e.id="holo-styles",e.textContent=j,document.head.appendChild(e)}function w({unlocked:e=!1,color:t="#14b8a6",children:x,className:h="",onClick:b}){const r=p.useRef(null),[i,l]=p.useState({x:0,y:0}),[d,u]=p.useState(!1),m=o=>{if(!r.current||!e)return;const s=r.current.getBoundingClientRect(),a=(o.clientX-s.left)/s.width,c=(o.clientY-s.top)/s.height;l({x:(c-.5)*-15,y:(a-.5)*15})},f=o=>{if(!r.current||!e)return;const s=o.touches[0],a=r.current.getBoundingClientRect(),c=(s.clientX-a.left)/a.width,y=(s.clientY-a.top)/a.height;l({x:(y-.5)*-10,y:(c-.5)*10})},g=()=>{l({x:0,y:0}),u(!1)};return n.jsx(v.div,{ref:r,onClick:b,onMouseMove:m,onMouseEnter:()=>u(!0),onMouseLeave:g,onTouchMove:f,onTouchEnd:g,className:`relative overflow-hidden cursor-pointer ${h}`,style:{perspective:600,transformStyle:"preserve-3d"},animate:{rotateX:i.x,rotateY:i.y,scale:d&&e?1.05:1},transition:{type:"spring",stiffness:300,damping:20},whileTap:e?{scale:.98}:{},children:n.jsxs("div",{className:`relative rounded-2xl border-b-[3px] transition-all duration-300 ${e?"bg-slate-800/80 border-slate-950":"bg-slate-900/40 border-slate-950 opacity-45"}`,style:e?{border:`1px solid ${t}30`,boxShadow:d?`0 10px 30px ${t}20, 0 0 15px ${t}15, inset 0 1px 1px ${t}10`:`0 4px 12px ${t}10, 0 0 1px ${t}20`}:{},children:[e&&n.jsxs(n.Fragment,{children:[n.jsx("div",{className:"absolute inset-0 rounded-2xl holo-rainbow pointer-events-none"}),n.jsx("div",{className:"absolute inset-0 rounded-2xl holo-glare pointer-events-none"})]}),e&&d&&n.jsx("div",{className:"absolute inset-0 rounded-2xl pointer-events-none",style:{background:`linear-gradient(${135+i.y*5}deg, ${t}15, transparent 40%, transparent 60%, ${t}15)`}}),n.jsx("div",{className:"relative z-10",children:x}),e&&n.jsx("div",{className:"absolute top-1 right-1 w-4 h-4 rounded-full flex items-center justify-center",style:{background:t,boxShadow:`0 0 6px ${t}80`},children:n.jsx("span",{className:"text-[7px] font-black text-white",children:"✓"})})]})})}export{w as H};
