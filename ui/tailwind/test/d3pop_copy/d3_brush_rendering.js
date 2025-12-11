/* D3 Brush Snapping Rendering
 * Based on https://observablehq.com/@d3/brush-snapping
 */

console.log('[D3 Brush Rendering] Script loaded');

function drawBrush(data, htmlComponent) {
    console.log('[drawBrush] Called with data:', data);
    
    // Clear any previous brush
    d3.select("svg").remove();
    
    // Get the container
    var container = d3.select('.brush-container');
    
    // Get dimensions
    var containerWidth = container.node().getBoundingClientRect().width;
    var containerHeight = container.node().getBoundingClientRect().height;
    
    // Set margins
    var margin = {top: 10, right: 20, bottom: 30, left: 20};
    var width = containerWidth - margin.left - margin.right;
    var height = containerHeight - margin.top - margin.bottom;
    
    // Create SVG
    var svg = container.append('svg')
        .attr('width', containerWidth)
        .attr('height', containerHeight);
    
    var g = svg.append('g')
        .attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');
    
    // Extract parameters from data
    var min = data.min || 0;
    var max = data.max || 100;
    var snapInterval = data.snapInterval || 1;
    var initialSelection = data.initialSelection || [min, max];
    
    // Create scale
    var xScale = d3.scaleLinear()
        .domain([min, max])
        .rangeRound([0, width]);
    
    // Create custom interval object for snapping (similar to d3.timeHour.every(12))
    var interval = {
        round: function(x) {
            return Math.round(x / snapInterval) * snapInterval;
        },
        floor: function(x) {
            return Math.floor(x / snapInterval) * snapInterval;
        },
        offset: function(x) {
            return x + snapInterval;
        }
    };
    
    // Create axis with grid lines
    var xAxis = function(g) {
        // Background grid
        var gridGroup = g.append('g')
            .attr('class', 'grid')
            .attr('transform', 'translate(0,' + (height - margin.bottom) + ')');
        
        gridGroup.call(d3.axisBottom(xScale)
            .ticks(Math.floor((max - min) / snapInterval))
            .tickSize(-(height - margin.top - margin.bottom))
            .tickFormat(function() { return null; }));
        
        gridGroup.select('.domain')
            .attr('fill', '#ddd')
            .attr('stroke', null);
        
        gridGroup.selectAll('.tick line')
            .attr('class', 'grid-line')
            .attr('stroke', '#fff')
            .attr('stroke-opacity', function(d) {
                // Make major grid lines more prominent
                return (d % (snapInterval * 2) === 0) ? 1 : 0.5;
            });
        
        // Foreground axis with labels
        var axisGroup = g.append('g')
            .attr('class', 'axis')
            .attr('transform', 'translate(0,' + (height - margin.bottom) + ')');
        
        axisGroup.call(d3.axisBottom(xScale)
            .ticks(Math.floor((max - min) / snapInterval / 2))
            .tickPadding(0));
        
        axisGroup.select('.domain').remove();
        
        axisGroup.selectAll('text')
            .attr('x', 0)
            .attr('text-anchor', 'middle');
    };
    
    // Add axis
    g.call(xAxis);
    
    // Create brush with snapping
    var brush = d3.brushX()
        .extent([[0, margin.top], [width, height - margin.bottom]])
        .on("start", brushStarted)
        .on("brush", brushed)
        .on("end", brushEnded);
    
    // Add brush group
    var brushGroup = g.append('g')
        .attr('class', 'brush')
        .call(brush);
    
    // Set initial brush selection
    if (initialSelection && initialSelection.length === 2) {
        brushGroup.call(brush.move, initialSelection.map(xScale));
    }
    
    // Brush start handler
    function brushStarted(event) {
        if (!event.sourceEvent) return;
        
        console.log('Brush started');
        
        // Send brushStart event to MATLAB using CustomEvent
        if (htmlComponent) {
            htmlComponent.dispatchEvent(new CustomEvent('BrushStarted', {
                detail: JSON.stringify({ type: 'brushStart' })
            }));
        }
    }
    
    // Brush event handler with snapping (following Observable pattern exactly)
    function brushed(event) {
        if (!event.sourceEvent) return; // Only transition after input
        
        var selection = event.selection;
        if (!selection) return;
        
        // Convert pixel coordinates to data coordinates
        var d0 = selection.map(xScale.invert);
        
        // Round to nearest interval
        var d1 = d0.map(interval.round);
        
        // If empty when rounded, use floor instead
        if (d1[0] >= d1[1]) {
            d1[0] = interval.floor(d0[0]);
            d1[1] = interval.offset(d1[0]);
        }
        
        // Apply snapped selection with smooth transition
        d3.select(this).transition()
            .duration(100)
            .call(brush.move, d1.map(xScale));
        
        // Send brushMove event to MATLAB using CustomEvent
        if (htmlComponent) {
            htmlComponent.dispatchEvent(new CustomEvent('BrushMoving', {
                detail: JSON.stringify({ 
                    type: 'brushMove',
                    selection: d1 
                })
            }));
        }
    }
    
    function brushEnded(event) {
        if (!event.selection) {
            console.log('Brush cleared');
            // Send cleared event using CustomEvent
            if (htmlComponent) {
                htmlComponent.dispatchEvent(new CustomEvent('ValueChanged', {
                    detail: JSON.stringify({ 
                        type: 'brushEnd',
                        selection: null 
                    })
                }));
            }
        } else {
            // Get the final snapped selection
            var selection = event.selection.map(xScale.invert);
            console.log('Brush selection: [' + selection[0].toFixed(1) + ', ' + selection[1].toFixed(1) + ']');
            
            // Send brushEnd event to MATLAB using CustomEvent
            if (htmlComponent) {
                htmlComponent.dispatchEvent(new CustomEvent('ValueChanged', {
                    detail: JSON.stringify({ 
                        type: 'brushEnd',
                        selection: selection 
                    })
                }));
            }
        }
    }
}
