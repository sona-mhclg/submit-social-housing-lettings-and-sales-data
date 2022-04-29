class CaseLogsController < ApplicationController
  include Pagy::Backend

  skip_before_action :verify_authenticity_token, if: :json_api_request?
  before_action :authenticate, if: :json_api_request?
  before_action :authenticate_user!, unless: :json_api_request?
  before_action :find_resource, except: %i[create index edit]

  def index
    set_session_filters

    @pagy, @case_logs = pagy(filtered_case_logs)

    respond_to do |format|
      format.html
      format.csv do
        send_data filtered_case_logs.to_csv, filename: "logs-#{Time.zone.now}.csv"
      end
    end
  end

  def create
    case_log = CaseLog.create(case_log_params)
    respond_to do |format|
      format.html { redirect_to case_log }
      format.json do
        if case_log.persisted?
          render json: case_log, status: :created
        else
          render json: { errors: case_log.errors.messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @case_log
      if @case_log.update(api_case_log_params)
        render json: @case_log, status: :ok
      else
        render json: { errors: @case_log.errors.messages }, status: :unprocessable_entity
      end
    else
      render_not_found_json("Log", params[:id])
    end
  end

  def show
    respond_to do |format|
      # We don't have a dedicated non-editable show view
      format.html { edit }
      format.json do
        if @case_log
          render json: @case_log, status: :ok
        else
          render_not_found_json("Log", params[:id])
        end
      end
    end
  end

  def edit
    @case_log = current_user.case_logs.find_by(id: params[:id])
    if @case_log
      render :edit
    else
      render_not_found
    end
  end

  def destroy
    if @case_log
      if @case_log.delete
        head :no_content
      else
        render json: { errors: @case_log.errors.messages }, status: :unprocessable_entity
      end
    else
      render_not_found_json("Log", params[:id])
    end
  end

private

  API_ACTIONS = %w[create show update destroy].freeze

  def json_api_request?
    API_ACTIONS.include?(request["action"]) && request.format.json?
  end

  def authenticate
    http_basic_authenticate_or_request_with name: ENV["API_USER"], password: ENV["API_KEY"]
  end

  def case_log_params
    if current_user
      org_params.merge(api_case_log_params)
    else
      api_case_log_params
    end
  end

  def org_params
    {
      "owning_organisation_id" => current_user.organisation.id,
      "managing_organisation_id" => current_user.organisation.id,
      "created_by_id" => current_user.id,
    }
  end

  def api_case_log_params
    return {} unless params[:case_log]

    permitted = params.require(:case_log).permit(CaseLog.editable_fields)
    permitted["owning_organisation"] = Organisation.find_by(permitted["owning_organisation"])
    permitted["managing_organisation"] = Organisation.find_by(permitted["managing_organisation"])
    permitted
  end

  def find_resource
    @case_log = CaseLog.find_by(id: params[:id])
  end

  def filtered_case_logs
    query = current_user.case_logs
    if session[:case_logs_filters].present?
      filters = JSON.parse(session[:case_logs_filters])
      filters.each do |category, values|
        next if values.reject(&:empty?).blank?

        query = query.public_send("filter_by_#{category}", values, current_user)
      end
    end
    current_user.support? ? query.all.includes(:owning_organisation, :managing_organisation) : query
  end

  def set_session_filters
    new_filters = session[:case_logs_filters].present? ? JSON.parse(session[:case_logs_filters]) : {}
    current_user.case_logs_filters.each { |filter| new_filters[filter] = params[filter] if params[filter].present? }
    session[:case_logs_filters] = new_filters.to_json
  end
end
