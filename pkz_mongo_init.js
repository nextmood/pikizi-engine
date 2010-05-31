db.system.js.save({_id : "has_value", value : function(p, e) { p = ensure_array(p); for (var i = 0; i < p.length; i++) { if (p[i] == e) return true; }; return false; }});
db.system.js.save({_id : "ensure_array", value : function(a) { if (!(a instanceof Array)) a = [a]; return a; }});
db.system.js.save({_id : "has_all", value : function(p, e) { p = ensure_array(p); e = ensure_array(e); for (var i = 0; i < e.length; i++) { if (!(has_value(p, e[i]))) return false; }; return true; }});
db.system.js.save({_id : "has_any", value : function(p, e) { p = ensure_array(p); e = ensure_array(e); for (var i = 0; i < e.length; i++) { if (has_value(p, e[i])) return true; }; return false; }});
