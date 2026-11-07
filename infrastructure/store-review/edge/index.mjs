// The only outbound service is a VPC binding pinned to the review API's port.
// The public hostname is used as HTTP Host so same-origin account deletion works.
const permitted = /^\/(?:health$|api\/v1\/(?:auth\/(?:login|refresh|register|account-deletion(?:\/web|\/capability)?)|devices\/(?:[A-Za-z0-9_-]+(?:\/(?:heartbeat|timeline))?)?|events\/(?:status\/[a-zA-Z0-9-]+|stats\/)?|(?:organizations|sites|zones|policies|calibration-profiles)\/(?:[A-Za-z0-9_-]+(?:\/devices)?|devices\/[A-Za-z0-9_-]+\/assignment)?|source-phases\/[A-Za-z0-9_-]+(?:\/[A-Za-z0-9-]+)?))$/;
const limit = 128 * 1024;
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol !== 'https:' || !permitted.test(url.pathname) ||
        !['GET','POST','PUT','DELETE'].includes(request.method)) return new Response(null,{status:404});
    if (Number(request.headers.get('content-length')) > limit) return new Response(null,{status:413});
    let body;
    if (request.body) {
      const reader = request.body.getReader(), chunks = []; let size = 0;
      for (;;) {
        const {value, done} = await reader.read(); if (done) break;
        size += value.length;
        if (size > limit) { await reader.cancel(); return new Response(null,{status:413}); }
        chunks.push(value);
      }
      body = new Uint8Array(size); let offset = 0;
      for (const part of chunks) { body.set(part, offset); offset += part.length; }
    }
    const headers = new Headers();
    for (const name of ['authorization','content-type','origin','x-device-key','accept']) {
      const val = request.headers.get(name); if (val) headers.set(name,val);
    }
    headers.set('x-forwarded-proto','https');
    url.protocol = 'http:';
    const response = await env.REVIEW_API.fetch(url.toString(), {method:request.method,headers,body,redirect:'manual'});
    const outgoing = new Response(response.body,response);
    outgoing.headers.set('Cache-Control','no-store');
    return outgoing;
  }
};
