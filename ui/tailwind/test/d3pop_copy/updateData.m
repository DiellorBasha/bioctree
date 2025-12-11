function updateData(~, year, chartLabel, populationPyramid, populationCoutns)
    % UPDATEDATA - Updates the Data property of the UIHTML component with
    % the newly selected year.
    % This will trigger a 'DataChanged' event to be emitted in JavaScript 
    chartLabel.Text = "    " + year + " Gender Split by age groups";

    dataToSend = struct('Year', str2double(year), 'PopulationCounts', populationCoutns);
    populationPyramid.Data = dataToSend;
    
end