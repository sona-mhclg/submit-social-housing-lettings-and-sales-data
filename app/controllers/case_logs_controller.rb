class CaseLogsController < ApplicationController
  def index
    @submitted_case_logs = CaseLog.where(status: 1)
    @in_progress_case_logs = CaseLog.where(status: 0)
  end

  def create
    @case_log = CaseLog.create!
    redirect_to @case_log
  end

  # We don't have a dedicated non-editable show view
  def show
    @case_log = CaseLog.find(params[:id])
    render :edit
  end

  def edit
    @case_log = CaseLog.find(params[:id])
  end

  def next_question
    subsection = params[:subsection]
    @case_log = CaseLog.find(params[:case_log_id])
    next_question = if subsection
               Form::FIRST_QUESTION_FOR_SUBSECTION[subsection]
             else
               previous_question = params[:previous_question]
               answer = params[previous_question]
               @case_log.update!(previous_question => answer)
               Form::QUESTIONS[previous_question]
             end
    render next_question, locals: { case_log_id: @case_log.id }
  end

  Form::QUESTIONS.keys.each do |question|
    define_method(question) do
      @case_log = CaseLog.find(params[:case_log_id])
      render "form/questions/#{question}", locals: { case_log_id: @case_log.id }
    end
  end
end
