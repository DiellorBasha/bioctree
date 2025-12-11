function populationCounts = generatePopulationCounts(year, country)
    % GENERATEDATA - Helper function to create population data
    populationCounts = [];
    for i = 1:size(year,2)
        age_bins = (10:10:110);
        age_bins=age_bins';
        year_column = repelem(year(1,i),10)';
        
        male_Population = round(normrnd(50,25,[100,1]));
        female_Population = round(normrnd(55,25,[100,1]));
    
        male = histcounts(male_Population,age_bins);
        female = histcounts(female_Population,age_bins);
        m_and_f = cat(2,male',female');
    
        combined_data = cat(2,age_bins(1:end-1),m_and_f);
        combined_data = cat(2,repelem(country,10)',combined_data);
        combined_data = cat(2,year_column,combined_data);
        populationCounts = [populationCounts;combined_data];
    end
    populationCounts = array2table(populationCounts);
    populationCounts.Properties.VariableNames = ["Year", "Country", "AgeGroup", "NumberOfMales", "NumberOfFemales"];
end