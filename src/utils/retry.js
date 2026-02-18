async function retry(fn, retries = 5, delay = 2000) {
    for (let i = 0; i < retries; i++) {
      try {
        return await fn()
      } catch (err) {
        console.log(`Retry attempt ${i + 1} failed`)
        if (i === retries - 1) throw err
        await new Promise(res => setTimeout(res, delay))
      }
    }
  }
  
  module.exports = retry  