import Bacon from 'baconjs'

const parseResponse = (result) => {
  if (result.status < 300) {
    if(result.headers.get('content-type').toLowerCase().startsWith('application/json')) {
      return Bacon.fromPromise(result.json())
    }
    return Bacon.fromPromise(result.text())
  }
  return new Bacon.Error({ message: 'http error ' + result.status, httpStatus: result.status })
}

const http = (url, options) => {
  const promise = fetch(url, options)
  return Bacon.fromPromise(promise).mapError({status: 503}).flatMap(parseResponse).toProperty()
}

http.get = (url) => http(url, { credentials: 'include' })
http.post = (url, entity) => http(url, { credentials: 'include', method: 'post', body: JSON.stringify(entity), headers: { 'Content-Type': 'application/json'} })

export default http
