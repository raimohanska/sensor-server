import React from 'react'
import ReactDOM from 'react-dom'
import styles from './main.less'
import http from './http.js'
import Bacon from 'baconjs'

class App extends React.Component {
	render () {
    let { data } = this.props
		return (
			<div>
        {
          data.components.map( c => {
            return <SliderControl key={c.valueKey} {...c} value={data.values[c.valueKey]} setValue={setValue}/>
          })
        }
			</div>
		)
	}
}

let SliderControl = React.createClass({
  render() {
    let { min, max, title, valueKey, setValue } = this.props
    let { value } = this.state
    let onChange = (e) => {
      let newValue = e.target.value
      this.setState({ value: newValue })
      let parsed = parseInt(newValue)
      let valid = !isNaN(parsed) && (max == undefined || parsed <= max) && (min == undefined || parsed >= min)
      if (valid)
        setValue(valueKey, parsed)
    }
    return (<label>{ title }
      <input type="text" value={value} onChange={onChange}/>
    </label>)
  },
  getInitialState() {
    return { value: this.props.value }
  }
})

let siteId = location.pathname.match(new RegExp('/site/(.*)/'))[1]
let valueBus = Bacon.Bus()
let setValue = (key, value) => {
  valueBus.push({key, value})
  console.log(key, value)
}

valueBus.throttle(500).onValue(({key, value}) => 
  http.post("/site/" + siteId + "/ui/values", {[key]: value})
)

http.get("/site/" + siteId + "/ui/state").onValue((state) => {
  console.log(state)
  let element = <App data={state}/>
  ReactDOM.render(element, document.getElementById('app'), null)
})
