/* Copyright 2019 The MathWorks, Inc. */

function drawD3Chart(year, populationCounts){
    // Clear the previous chart, if any
    d3.select("svg").remove();

    var svg = d3.select('.chart-container').append('svg');

    var width_svg = +svg.node().getBoundingClientRect().width,
    height_svg = +svg.node().getBoundingClientRect().height;
    var left = 0.04;
    var top= 0.04;
    var margin = {
        top: height_svg*top,
        right: width_svg*left,
        bottom: height_svg*2*top,
        left: width_svg*left
    };

    var width = width_svg - margin.left - margin.right;
    var height = height_svg - margin.top - margin.bottom;
        
    // Makes this responsive
    d3.select('svg').attr('viewBox','0 0 '+width_svg+' '+height_svg).attr('preserveAspectRatio','xMinYMin meet');

    populationCounts.forEach(function(d,i){
        d.AgeGroup = "Age < "+d.AgeGroup;	
        d.Year = ""+d.Year;

    });

    //Filter data for specific year and roll up by country  
    var data_for_year = populationCounts.filter(function(d,i) { return d.Year==year;});

    // setting up y axis components 
    var yDomain = data_for_year.map(function(d){ return d.AgeGroup; });	
    var y = d3.scaleBand()
            .range([0, height])
            .domain(yDomain)
            .paddingInner(0.2).paddingOuter(0.35)

    // setting up x axis components 
    var xDomain = d3.extent(data_for_year, function (d) {
                return Math.max(d.NumberOfFemales, d.NumberOfMales);
            });	

    //adjust width for central y axis:
    var width_adjusted = (1/2 - (left)) * width;

    var x = d3.scaleLinear()
            .range([0, (width_adjusted)]) //more cushion - each side of the bar raph takes up only 46% of the width
            .domain([0,xDomain[1]])				

    //for male/female reverse axis
    var rev_x_domain = [xDomain[1],0];

    //Setting up 2 separate groups for holding the male and female rectangles
    var groups = svg
        .append('g')
        .attr('class', "groups_m")
        .attr('transform',"translate(-"+margin.left+"," + (y.bandwidth()) +")" )

    var groups2 = svg
        .append('g')
        .attr('class', "groups_f" )
        .attr('transform',"translate("+margin.left+"," + y.bandwidth()+")" )

    //A new div to hold the tooltips on demand
    var div = d3.select("body").append("div")	
            .attr("class", "tooltip")				
            .style("opacity", 0)
            .style('position','absolute');

    //Actual creation of rectangles happen here, one set of Male rectangles and one set of Female rectangles per country 
    x.domain([0,xDomain[1]]);
            
    //Create Female rectangles
    var f_rect = d3.selectAll(".groups_f").selectAll(".bar_f")
        .data(data_for_year)
        .enter()
        .append('rect');

    f_rect.attr('class', "bar_f")
        .attr('x', (width_adjusted) + 2*margin.left)
        .attr('y', function(d){  return y(d.AgeGroup);  })
        .attr('height', y.bandwidth())
        .style('fill', '#F265A7')
        .transition()
        .duration(400)
        .delay(function(d,i){ return i*150} )
        .ease(d3.easeSinInOut)
        .attr('width', function(d) { return x(d.NumberOfFemales); })

    // Configure the tooltip action on mouse over and mouse out events for Female rectangles
    f_rect.on("mouseover", function(d) {					
        d3.select(this).style('fill', '#FF99CB')				
        div.transition()		
        .duration(200)
        .delay(150)
        .ease(d3.easeExpInOut)	
        .style("opacity", .9);		
        div.html( (d.Country)+ " - Females whose "+(d.AgeGroup).toLowerCase() +" <b> : "+ d.NumberOfFemales+" </b>")	
        .style("left", d3.event.pageX )		
        .style("top", d3.event.pageY );	
    })					
    .on("mouseout", function(d) {		
        d3.select(this).style('fill', '#F265A7')
        div.transition()		
        .duration(500)		
        .style("opacity", 0);	
    });			  

    //Create Male rectangles
    var m_rect = d3.selectAll(".groups_m").selectAll(".bar_m")
        .data(data_for_year)
        .enter()
        .append('rect');

    m_rect.attr('class', "bar_m")
        .attr('y', function(d){return y(d.AgeGroup);  })
        .attr('height', y.bandwidth()) 
        .attr('width', 0)
        .attr('x', (width_adjusted) + 2*margin.left )
        .style('fill', '#487FE8') 
        .transition()
        .duration(400) 
        .delay(function(d,i){ return i*150} )
        .ease(d3.easeSinInOut)
        .attr('x',function(d) { return (width_adjusted)+ 2*margin.left - x(d.NumberOfMales) } )
        .attr('width', function(d){ return x(d.NumberOfMales); });


    // Configure the tooltip action on mouse over and mouse out events for male rectangles
    m_rect.on("mouseover", function(d) {
        d3.select(this).style('fill', '#6AB5EB')
        div.transition()		
        .duration(250)	
        .delay(150)
        .ease(d3.easeExpInOut)					
        .style("opacity", .9);			
        div.html( (d.Country)+ " - Males whose " + (d.AgeGroup).toLowerCase() +"   <b> :  "+ d.NumberOfMales +" </b>")	
        .style("left", d3.event.pageX -120 )
        .style("top", d3.event.pageY );

    })					
    .on("mouseout", function(d) {		
        div.transition()		
        .duration(500)		
        .style("opacity", 0);
        d3.select(this).style('fill', '#487FE8')					
    });

    //Build y-axis   
    svg.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + ((width_adjusted)+(margin.left)+(margin.right)) + ","+ (y.bandwidth()/2+margin.top)+")")
        .call(d3.axisLeft(y).tickSize(0))
        .style("text-anchor", "middle")
        .style("font", "62% helvetica")
        .select(".domain").remove();

    //Build x-axis on the female side
    d3.select('.groups_f').append('g')
        .attr('class', 'x-axis female_axis')
        .call(d3.axisBottom(x).tickSize(0))
        .style("font", "62% helvetica")
        .attr("stroke-width", 0.5)
        .attr("text-anchor", "middle")
        .attr('transform', 'translate('+(width_adjusted+ 2*(margin.left))+',' + (height-margin.top/2)  + ')');


    // Male axis needs to go from inside to outside, and hence we reverse the domain
    x.domain(rev_x_domain)

    // Build x-axis on the male side
    d3.select('.groups_m').append('g')
        .attr('class', 'x-axis male_axis')
        .call(d3.axisBottom(x).tickSize(0))
        .style("font", "62% helvetica")
        .attr("stroke-width", 0.5)
        .attr("text-anchor", "middle")
        .attr('transform', 'translate('+ (width_adjusted + 2*margin.left- x(0))+',' + (height-margin.top/2) + ')');

    // Text label for the x axis
    svg.append("text")
        .attr("y", height+margin.bottom)
        .attr("x", width/2+margin.left)
        .style("font", "72% helvetica")
        .style("text-anchor", "middle")
        .text("counts");

    //set the x domain back straight to build female axis in next country's iteration			
    x.domain([0,xDomain[1]])  
}