extends RefCounted

## Web music: the browser streams and decodes the track (HTMLAudioElement -> Web Audio gain), so playback never
## depends on the game's frame rate. Without threads Godot mixes on the main thread into a ~50 ms ring buffer: any
## frame longer than that starved it (gaps at low fps), and MP3 decode ran inside those frames (chunky fps).
## Tracks are served next to index.html (tools/web_postexport.py copies them to music/; the pck excludes them).
## A missing or broken track is an error in the console and in Godot (no silent fallback).

const JS := """
(function(){if(window.wdbMusic)return;var M=window.wdbMusic={el:{},cx:null,g:null,cur:'',v:1,loop:0,onerr:null};
function ctx(){if(!M.cx){M.cx=new (window.AudioContext||window.webkitAudioContext)();M.g=M.cx.createGain();M.g.gain.value=M.v;M.g.connect(M.cx.destination);
['pointerdown','keydown','touchstart'].forEach(function(k){window.addEventListener(k,function(){if(M.cx.state!=='running')M.cx.resume()},true)})}
return M.cx}
function url(n){return 'music/'+n+'?v='+(window.__wdbBuildId||'dev')}
function el(n){var a=M.el[n];if(a)return a;a=new Audio();a.preload='auto';a.crossOrigin='anonymous';a.src=url(n);
a.addEventListener('error',function(){var m='WDB music: failed to load '+a.src+' (code '+(a.error&&a.error.code)+')';console.error(m);if(M.onerr)M.onerr(m)});
a.addEventListener('ended',function(){if(M.cur===n&&M.loop>=0){a.currentTime=M.loop;a.play()}});
M.el[n]=a;return a}
M.fetch=function(n){el(n)};
M.play=function(n,loop){var c=ctx();M.stop();var a=el(n);if(!a.src_node){a.src_node=c.createMediaElementSource(a);a.src_node.connect(M.g)}
M.cur=n;M.loop=loop;a.loop=false;a.currentTime=0;if(c.state!=='running')c.resume();
var p=a.play();if(p)p.catch(function(e){if(e&&e.name!=='AbortError'&&e.name!=='NotAllowedError'){console.error('WDB music: '+e);if(M.onerr)M.onerr(String(e))}})};
M.stop=function(){var a=M.el[M.cur];M.cur='';if(a)a.pause()};
M.vol=function(v){M.v=v;if(M.g)M.g.gain.value=v};})();
"""

var _err_cb: JavaScriptObject

func _init() -> void:
	JavaScriptBridge.eval(JS, true)
	_err_cb = JavaScriptBridge.create_callback(_on_err)
	JavaScriptBridge.get_interface("wdbMusic").onerr = _err_cb

func _on_err(args: Array) -> void:
	push_error(str(args[0]) if args.size() > 0 else "WDB music: playback error")

## Start the download early; the browser buffers by time, off the game loop.
func fetch(file: String) -> void:
	JavaScriptBridge.eval("wdbMusic.fetch(%s)" % JSON.stringify(file), true)

## loop_from < 0: play once; else on end jump back to loop_from seconds.
func play(file: String, loop_from: float) -> void:
	JavaScriptBridge.eval("wdbMusic.play(%s,%s)" % [JSON.stringify(file), str(loop_from)], true)

func stop() -> void:
	JavaScriptBridge.eval("wdbMusic.stop()", true)

func volume(v: float) -> void:
	JavaScriptBridge.eval("wdbMusic.vol(%s)" % str(v), true)
