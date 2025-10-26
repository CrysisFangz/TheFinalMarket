require 'report_presenter'

class Admin::AbTestsController < Admin::BaseController
  def index
    @experiments_result = AbTestingService.all_experiments
    if @experiments_result.success?
      @experiments = @experiments_result.data
      @active_experiments = @experiments.select(&:enabled?)
      @completed_experiments = @experiments.reject(&:enabled?)
    else
      @experiments = []
      @active_experiments = []
      @completed_experiments = []
      flash[:error] = @experiments_result.message
    end
  end

  def show
    @experiment_result = AbTestingService.get_experiment(params[:id])
    if @experiment_result.success?
      @experiment = @experiment_result.data
      @results = AbTestingService.experiment_results(params[:id])
    else
      flash[:error] = @experiment_result.message
      redirect_to admin_ab_tests_path
    end
  end

  def new
    @experiment = Split::Experiment.new
  end

  def create
    result = AbTestingService.register_experiment(
      name: params[:name],
      variants: params[:variants].split(',').map(&:strip),
      description: params[:description],
      traffic_percentage: params[:traffic_percentage]
    )

    if result.success?
      redirect_to admin_ab_tests_path, notice: 'Experiment was successfully created.'
    else
      flash[:error] = result.message
      render :new
    end
  end

  def update
    case params[:action_type]
    when 'start'
      result = AbTestingService.start_experiment(params[:id])
    when 'pause'
      result = AbTestingService.pause_experiment(params[:id])
    when 'resume'
      result = AbTestingService.resume_experiment(params[:id])
    when 'reset'
      result = AbTestingService.reset_experiment(params[:id])
    when 'delete'
      result = AbTestingService.delete_experiment(params[:id])
    end

    if result.success?
      notice = case params[:action_type]
               when 'start' then 'Experiment started'
               when 'pause' then 'Experiment paused'
               when 'resume' then 'Experiment resumed'
               when 'reset' then 'Experiment reset'
               when 'delete' then 'Experiment deleted'
               end
      redirect_to admin_ab_tests_path, notice: notice
    else
      redirect_to admin_ab_tests_path, alert: result.message
    end
  end

  def report
    @experiment_result = AbTestingService.get_experiment(params[:id])
    if @experiment_result.success?
      @experiment = @experiment_result.data
      @results = AbTestingService.experiment_results(params[:id])
      
      respond_to do |format|
        format.html
        format.json { render json: @results }
        format.csv { send_data ReportPresenter.new(@results.data).to_csv, filename: "ab-test-#{params[:id]}.csv" }
      end
    else
      flash[:error] = @experiment_result.message
      redirect_to admin_ab_tests_path
    end
  end

  end