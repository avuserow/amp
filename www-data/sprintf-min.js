// http://kevin.vanzonneveld.net
// +   original by: Ash Searle (http://hexmen.com/blog/)
// + namespaced by: Michael White (http://getsprink.com)
// +    tweaked by: Jack
// +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
// +      input by: Paulo Ricardo F. Santos
// +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
// +      input by: Brett Zamir (http://brett-zamir.me)
// +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
// *     example 1: sprintf("%01.2f", 123.1);
// *     returns 1: 123.10
// *     example 2: sprintf("[%10s]", 'monkey');
// *     returns 2: '[    monkey]'
// *     example 3: sprintf("[%'#10s]", 'monkey');
// *     returns 3: '[####monkey]'

function sprintf(){var a=/%%|%(\d+\$)?([-+\'#0 ]*)(\*\d+\$|\*|\d+)?(\.(\*\d+\$|\*|\d+))?([scboxXuidfegEG])/g,b=arguments,c=0,d=b[c++],e=function(a,b,c,d){c||(c=" ");var e=a.length>=b?"":Array(1+b-a.length>>>0).join(c);return d?a+e:e+a},f=function(a,b,c,d,f,g){var h=d-a.length;h>0&&(c||!f?a=e(a,d,g,c):a=a.slice(0,b.length)+e("",h,"0",true)+a.slice(b.length));return a},g=function(a,b,c,d,g,h,i){var j=a>>>0;c=c&&j&&({2:"0b",8:"0",16:"0x"})[b]||"",a=c+e(j.toString(b),h||0,"0",false);return f(a,c,d,g,i)},h=function(a,b,c,d,e,g){d!=null&&(a=a.slice(0,d));return f(a,"",b,c,e,g)},i=function(a,d,i,j,k,l,m){var n,o,p,q,r;if(a=="%%")return"%";var s=false,t="",u=false,v=false,w=" ",x=i.length;for(var y=0;i&&y<x;y++)switch(i.charAt(y)){case" ":t=" ";break;case"+":t="+";break;case"-":s=true;break;case"'":w=i.charAt(y+1);break;case"0":u=true;break;case"#":v=true}j?j=="*"?j=+b[c++]:j.charAt(0)=="*"?j=+b[j.slice(1,-1)]:j=+j:j=0,j<0&&(j=-j,s=true);if(!isFinite(j))throw new Error("sprintf: (minimum-)width must be finite");l?l=="*"?l=+b[c++]:l.charAt(0)=="*"?l=+b[l.slice(1,-1)]:l=+l:l="fFeE".indexOf(m)>-1?6:m=="d"?0:undefined,r=d?b[d.slice(0,-1)]:b[c++];switch(m){case"s":return h(String(r),s,j,l,u,w);case"c":return h(String.fromCharCode(+r),s,j,l,u);case"b":return g(r,2,v,s,j,l,u);case"o":return g(r,8,v,s,j,l,u);case"x":return g(r,16,v,s,j,l,u);case"X":return g(r,16,v,s,j,l,u).toUpperCase();case"u":return g(r,10,v,s,j,l,u);case"i":case"d":n=parseInt(+r,10),o=n<0?"-":t,r=o+e(String(Math.abs(n)),l,"0",false);return f(r,o,s,j,u);case"e":case"E":case"f":case"F":case"g":case"G":n=+r,o=n<0?"-":t,p=["toExponential","toFixed","toPrecision"]["efg".indexOf(m.toLowerCase())],q=["toString","toUpperCase"]["eEfFgG".indexOf(m)%2],r=o+Math.abs(n)[p](l);return f(r,o,s,j,u)[q]();default:return a}};return d.replace(a,i)}
