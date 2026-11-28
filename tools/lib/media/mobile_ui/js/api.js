// Studio JSON API. Every call resolves to {ok, status, data}; it never throws on HTTP errors.
export async function api(method, path, body) {
  try {
    const res = await fetch("/api/studio" + path, {
      method,
      headers: body ? { "Content-Type": "application/json" } : {},
      body: body ? JSON.stringify(body) : undefined,
      cache: "no-store",
    });
    let data = {};
    try { data = await res.json(); } catch (e) { data = { error: `HTTP ${res.status}` }; }
    return { ok: res.ok, status: res.status, data };
  } catch (e) {
    return { ok: false, status: 0, data: { error: "The studio server did not answer. Is it running on the PC?" } };
  }
}

export const get = (path) => api("GET", path);
export const post = (path, body) => api("POST", path, body || {});

export function fileUrl(path, bust) {
  return "/api/studio/file?path=" + encodeURIComponent(path) + (bust ? "&t=" + Math.round(bust) : "");
}
