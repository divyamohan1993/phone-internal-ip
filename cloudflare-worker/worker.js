addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
  })
  
  async function handleRequest(request) {
    const url = new URL(request.url)
  
    // POST /update
    if (request.method === 'POST' && url.pathname === '/update') {
      let data
      try {
        data = await request.json()
      } catch {
        return new Response('Bad JSON', { status: 400 })
      }
      if (data.key !== UPDATE_SECRET || !data.ip) {
        return new Response('Unauthorized or missing ip', { status: 401 })
      }
      const now = new Date().toISOString()
      await IP_KV.put('latest', JSON.stringify({ ip: data.ip, ts: now }))
      return new Response('OK', { status: 200 })
    }
  
    // GET /
    if (request.method === 'GET' && url.pathname === '/') {
      const raw = await IP_KV.get('latest')
      if (!raw) {
        return new Response('IP not set', {
          status: 404,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
          }
        })
      }
      const { ip, ts } = JSON.parse(raw)
      const d = new Date(ts)
      const datePart = d.toLocaleDateString('en-US', {
        timeZone: 'Asia/Kolkata', year: 'numeric', month: 'long', day: 'numeric'
      })
      const timePart = d.toLocaleTimeString('en-US', {
        timeZone: 'Asia/Kolkata', hour12: false,
        hour: '2-digit', minute: '2-digit', second: '2-digit'
      })
      const body = `IP: ${ip}\nUpdated: ${datePart} ${timePart}`
  
      return new Response(body, {
        status: 200,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        }
      })
    }
  
  
    return new Response('Not found', { status: 404 })
  }