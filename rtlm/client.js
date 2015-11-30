var url = "ws://192.168.67.35/rtlm?item=kernel"
var wscli = new WebSocket(url)
var count = 0
var begin = 0

wscli.onmessage = function  (event) {
    var root = document.getElementById("rtlm")
    if (count >= 200){
        beginElement = document.getElementById("div" + begin)
        root.removeChild(beginElement)
        begin = begin + 1
    }

    message = event.data
    messages = message.replace(/\n/g, '<br />')
    var divId = "div" + count
    
    addElement = document.createElement("div")
    addElement.setAttribute("id", divId)
    addElement.innerHTML = messages
    root.appendChild(addElement)
    count = count + 1
}

wscli.onclose = function(){
    alert("WebSocket disconnect")
}

wscli.onopen = function(){
    alert("WebSocket connected")
}

wscli.onerror = function(){
    alert("ERROR")
}
