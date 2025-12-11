/* Simple D3 Scatter Plot Rendering with Brush Snapping */

function drawScatterPlot(data) {
    // Clear any previous chart
    d3.select("svg").remove();
    
    // Get the container and create SVG
    var container = d3.select('.chart-container');
    var svg = container.append('svg');
    
    // Get dimensions
    var containerWidth = container.node().getBoundingClientRect().width;
    var containerHeight = container.node().getBoundingClientRect().height;
    
    // Set margins
    var margin = {top: 40, right: 40, bottom: 60, left: 60};
    var width = containerWidth - margin.left - margin.right;
    var height = containerHeight - margin.top - margin.bottom;
    
    // Make responsive
    svg.attr('viewBox', '0 0 ' + containerWidth + ' ' + containerHeight)
       .attr('preserveAspectRatio', 'xMinYMin meet');
    
    // Create main group for chart
    var g = svg.append('g')
        .attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');
    
    // Convert MATLAB arrays to JavaScript array of objects
    var plotData = [];
    for (var i = 0; i < data.x.length; i++) {
        plotData.push({
            x: data.x[i],
            y: data.y[i],
            index: i
        });
    }
    
    // Create scales
    var xExtent = d3.extent(plotData, function(d) { return d.x; });
    var yExtent = d3.extent(plotData, function(d) { return d.y; });
    
    // Add some padding to the scales
    var xPadding = (xExtent[1] - xExtent[0]) * 0.1;
    var yPadding = (yExtent[1] - yExtent[0]) * 0.1;
    
    var xScale = d3.scaleLinear()
        .domain([xExtent[0] - xPadding, xExtent[1] + xPadding])
        .range([0, width]);
    
    var yScale = d3.scaleLinear()
        .domain([yExtent[0] - yPadding, yExtent[1] + yPadding])
        .range([height, 0]);  // Inverted for SVG coordinates
    
    // Define snap interval (snap to nearest 0.5 units in data space)
    var snapInterval = 0.5;
    
    // Create axes
    var xAxis = d3.axisBottom(xScale);
    var yAxis = d3.axisLeft(yScale);
    
    // Add X axis
    g.append('g')
        .attr('class', 'axis')
        .attr('transform', 'translate(0,' + height + ')')
        .call(xAxis);
    
    // Add Y axis
    g.append('g')
        .attr('class', 'axis')
        .call(yAxis);
    
    // Add X axis label
    g.append('text')
        .attr('class', 'axis-label')
        .attr('text-anchor', 'middle')
        .attr('x', width / 2)
        .attr('y', height + 45)
        .text('X Values');
    
    // Add Y axis label
    g.append('text')
        .attr('class', 'axis-label')
        .attr('text-anchor', 'middle')
        .attr('transform', 'rotate(-90)')
        .attr('x', -height / 2)
        .attr('y', -45)
        .text('Y Values');
    
    // Add title
    g.append('text')
        .attr('class', 'axis-label')
        .attr('text-anchor', 'middle')
        .attr('x', width / 2)
        .attr('y', -15)
        .style('font-size', '16px')
        .text('Scatter Plot (' + plotData.length + ' points)');
    
    // Draw points
    var dots = g.selectAll('.dot')
        .data(plotData)
        .enter()
        .append('circle')
        .attr('class', 'dot')
        .attr('cx', function(d) { return xScale(d.x); })
        .attr('cy', function(d) { return yScale(d.y); })
        .attr('r', 5);
    
    // Create brush with snapping
    var brush = d3.brush()
        .extent([[0, 0], [width, height]])
        .on("brush", brushed)
        .on("end", brushEnded);
    
    // Add brush group
    var brushGroup = g.append('g')
        .attr('class', 'brush')
        .call(brush);
    
    // Brush event handler with snapping
    function brushed(event) {
        if (!event.sourceEvent) return;
        if (!event.selection) {
            // Clear selection
            dots.classed('selected', false);
            return;
        }
        
        // Get the brush selection in pixel coordinates
        var [[x0, y0], [x1, y1]] = event.selection;
        
        // Convert to data coordinates
        var xDataRange = [xScale.invert(x0), xScale.invert(x1)];
        var yDataRange = [yScale.invert(y1), yScale.invert(y0)]; // Inverted because y-scale is inverted
        
        // Snap to nearest interval
        var snappedX0 = Math.floor(xDataRange[0] / snapInterval) * snapInterval;
        var snappedX1 = Math.ceil(xDataRange[1] / snapInterval) * snapInterval;
        var snappedY0 = Math.floor(yDataRange[0] / snapInterval) * snapInterval;
        var snappedY1 = Math.ceil(yDataRange[1] / snapInterval) * snapInterval;
        
        // If the snapped range is too small, expand it
        if (snappedX1 - snappedX0 < snapInterval) {
            snappedX1 = snappedX0 + snapInterval;
        }
        if (snappedY1 - snappedY0 < snapInterval) {
            snappedY1 = snappedY0 + snapInterval;
        }
        
        // Convert back to pixel coordinates
        var snappedPixelX0 = xScale(snappedX0);
        var snappedPixelX1 = xScale(snappedX1);
        var snappedPixelY0 = yScale(snappedY1); // Inverted
        var snappedPixelY1 = yScale(snappedY0); // Inverted
        
        // Apply snapped selection with smooth transition
        d3.select(brushGroup.node()).transition()
            .duration(100)
            .call(brush.move, [[snappedPixelX0, snappedPixelY0], [snappedPixelX1, snappedPixelY1]]);
        
        // Highlight selected points
        dots.classed('selected', function(d) {
            return d.x >= snappedX0 && d.x <= snappedX1 &&
                   d.y >= snappedY0 && d.y <= snappedY1;
        });
    }
    
    function brushEnded(event) {
        if (!event.selection) {
            dots.classed('selected', false);
            console.log('Brush cleared');
            return;
        }
        
        // Get final selection and report to console
        var selectedData = plotData.filter(function(d) {
            var [[x0, y0], [x1, y1]] = event.selection;
            var xd0 = xScale.invert(x0);
            var xd1 = xScale.invert(x1);
            var yd0 = yScale.invert(y1); // Inverted
            var yd1 = yScale.invert(y0); // Inverted
            return d.x >= xd0 && d.x <= xd1 && d.y >= yd0 && d.y <= yd1;
        });
        
        console.log('Selected ' + selectedData.length + ' points:', selectedData);
    }
}
