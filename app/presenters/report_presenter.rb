# frozen_string_literal: true

class ReportPresenter
  def initialize(results)
    @results = results
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      # Basic experiment info
      csv << ['Experiment Name', @results[:name]]
      csv << ['Start Date', @results[:start_date]]
      csv << ['Total Participants', @results[:participants]]
      csv << []

      # Variant results
      csv << ['Variant', 'Participants', 'Completions', 'Conversion Rate', 'Z-Score', 'Confidence Level']
      @results[:alternatives].each do |alt|
        csv << [
          alt[:name],
          alt[:participants],
          alt[:completed],
          "#{(alt[:conversion_rate] * 100).round(2)}%",
          alt[:z_score],
          alt[:confidence_level]
        ]
      end
      csv << []

      # Goal completions
      @results[:goals].each do |goal|
        csv << ["Goal: #{goal[:name]}"]
        csv << ['Variant', 'Completions']
        goal[:completion_counts].each do |count|
          csv << [count[:variant], count[:count]]
        end
        csv << []
      end
    end
  end
end