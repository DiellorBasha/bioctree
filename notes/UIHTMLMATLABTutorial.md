
---

# Create HTML Content in Apps

You can add HTML content, including JavaScript®, CSS, and third-party visualizations or widgets, to your app by using an **HTML UI component**. Use the `uihtml` function to create an HTML UI component.

When you add an HTML UI component to your app, write code to communicate between MATLAB® and JavaScript. You can:

* Set component data
* Respond to changes in data
* React to user interaction by sending events

---

## Communicate Between MATLAB and JavaScript

To connect the MATLAB HTML UI component in your app to your HTML content, implement a `setup` function in your HTML file.

The `setup` function:

* Defines and initializes a local JavaScript `htmlComponent` object
* Synchronizes with the MATLAB HTML object
* Is accessible **only within the `setup` function**

```html
<script type="text/javascript">
    function setup(htmlComponent) {
        // Access the htmlComponent object here
    }
</script>
```

---

### When the `setup` Function Executes

The `setup` function executes whenever:

* The HTML UI component is created in the UI figure and the content has fully loaded
* The `HTMLSource` property of the MATLAB HTML object changes to a new value

---

## Communication Approaches

With this connection, you can share information between MATLAB and JavaScript using the following approaches:

### Share Component Data

Use this approach when your HTML component has **static data** that must be accessed by both MATLAB and JavaScript.

Example: A table stored as shared component data.

---

### Send Component Events

Use this approach to broadcast **notifications of changes or interactions**.

Examples:

* Send an event from JavaScript when a user clicks a button
* Send an event from MATLAB to trigger behavior in JavaScript

---

## Communication Overview

| Task                        | MATLAB                                                  | JavaScript                                                            |
| --------------------------- | ------------------------------------------------------- | --------------------------------------------------------------------- |
| **Access component object** | MATLAB represents the UI component as an `HTML` object. | JavaScript represents the UI component as the `htmlComponent` object. |
|                             | `matlab fig = uifigure; c = uihtml(fig); `              | `html <script> function setup(htmlComponent) { } </script> `          |

---

## Access Component Data

### MATLAB

The MATLAB HTML object has a `Data` property synchronized with JavaScript.

```matlab
fig = uifigure;
c = uihtml(fig);
c.Data = 10;
```

---

### JavaScript

The JavaScript `htmlComponent` object has a `Data` property synchronized with MATLAB.

```html
<script type="text/javascript">
    function setup(htmlComponent) {
        htmlComponent.Data = 5;
    }
</script>
```

---

## Respond to a Change in Component Data

### MATLAB: `DataChangedFcn`

```matlab
fig = uifigure;
c = uihtml(fig);
c.DataChangedFcn = @(src,event) disp(event.Data);
```

---

### JavaScript: `DataChanged` Event Listener

```javascript
htmlComponent.addEventListener("DataChanged", updateData);

function updateData(event) {
    let changedData = htmlComponent.Data;
    // Update HTML or JavaScript with the new data
}
```

For more information, see
[EventTarget.addEventListener() – MDN](https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener)

---

## Send and React to an Event from MATLAB in JavaScript

### MATLAB: Send Event

```matlab
fig = uifigure;
c = uihtml(fig);
eventData = [1 2 3];
sendEventToHTMLSource(c, "myMATLABEvent", eventData);
```

---

### JavaScript: React to MATLAB Event

```javascript
htmlComponent.addEventListener("myMATLABEvent", processEvent);

function processEvent(event) {
    let eventData = event.Data;
    // React to the event
}
```

---

## Send and React to an Event from JavaScript in MATLAB

### MATLAB: React to JavaScript Event

```matlab
fig = uifigure;
c = uihtml(fig);
c.HTMLEventReceivedFcn = @(src,event) disp(event);
```

---

### JavaScript: Send Event to MATLAB

```javascript
eventData = [1,2,3];
htmlComponent.sendEventToMATLAB("myHTMLEvent", eventData);
```

---

## Convert Data Between MATLAB and JavaScript

You can pass two types of data:

* **Component data** (via `Data` property)
* **Event data** (via events)

Because MATLAB and JavaScript support different data types, data is converted automatically.

---

### MATLAB → JavaScript Conversion

1. MATLAB encodes data using `jsonencode`
2. JavaScript parses using `JSON.parse`

---

### JavaScript → MATLAB Conversion

1. JavaScript encodes data using `JSON.stringify`
2. MATLAB parses using `jsondecode`

You can simulate this behavior using these functions to debug communication.

---

## Sample HTML Source File

Save the following code as `sampleHTMLFile.html`.

This sample creates:

* An edit field for component data
* An edit field for event data
* A button to send events to MATLAB

---

### HTML Source

```html
<!DOCTYPE html>
<html>
<head>
    <script type="text/javascript">
        function setup(htmlComponent) {
            console.log("Setup called:", htmlComponent);

            htmlComponent.addEventListener("DataChanged", dataFromMATLABToHTML);
            htmlComponent.addEventListener("MyMATLABEvent", eventFromMATLABToHTML);

            let dataInput = document.getElementById("compdata");
            dataInput.addEventListener("change", dataFromHTMLToMATLAB);

            let eventButton = document.getElementById("send");
            eventButton.addEventListener("click", eventFromHTMLToMATLAB);

            function dataFromMATLABToHTML(event) {
                let changedData = htmlComponent.Data;
                document.getElementById("compdata").value = changedData;
            }

            function eventFromMATLABToHTML(event) {
                let eventData = event.Data;
                document.getElementById("evtdata").value = eventData;
            }

            function dataFromHTMLToMATLAB(event) {
                let newData = event.target.value;
                htmlComponent.Data = newData;
            }

            function eventFromHTMLToMATLAB(event) {
                let eventData = document.getElementById("evtdata").value;
                htmlComponent.sendEventToMATLAB("MyHTMLSourceEvent", eventData);
            }
        }
    </script>
</head>

<body>
    <div style="font-family:sans-serif;">
        <label>Component data:</label>
        <input type="text" id="compdata"><br><br>

        <label>Event data:</label>
        <input type="text" id="evtdata"><br><br>

        <button id="send">Send event to MATLAB</button>
    </div>
</body>
</html>
```

---

## MATLAB Usage Example

```matlab
fig = uifigure;
h = uihtml(fig, ...
    "HTMLSource","sampleHTMLFile.html", ...
    "DataChangedFcn",@(src,event) disp(src.Data), ...
    "HTMLEventReceivedFcn",@(src,event) disp(event.HTMLEventData), ...
    "Position",[20 20 200 200]);
```

---

### Update Component Data

```matlab
h.Data = "My component data";
```

---

### Send Event from MATLAB to JavaScript

```matlab
sendEventToHTMLSource(h, "MyMATLABEvent", "My event data");
```

---

### User Interaction Flow

1. User edits component data → `DataChangedFcn` executes in MATLAB
2. User clicks **Send event to MATLAB** → `HTMLEventReceivedFcn` executes

---

## See Also

### Functions

* `uihtml`
* `sendEventToHTMLSource`
* `jsonencode`
* `jsondecode`

### Objects

* `HTML`

### Topics

* Debug HTML Content in Apps
* Display HTML Content in an App

---

