class FormController < ApplicationController
  before_action :authenticate_user!
  before_action :find_resource, only: %i[submit_form review]
  before_action :find_resource_by_named_id, except: %i[submit_form review]

  def submit_form
    if @case_log
      @page = @case_log.form.get_page(params[:case_log][:page])
      responses_for_page = responses_for_page(@page)
      if @case_log.update(responses_for_page)
        session[:errors] = nil
        if is_referrer_check_answers? && !@case_log.form.next_page(@page, @case_log).to_s.include?("value_check")
          redirect_to(send("case_log_#{@case_log.form.subsection_for_page(@page).id}_check_answers_path", @case_log))
        else
          redirect_path = @case_log.form.next_page_redirect_path(@page, @case_log)
          redirect_to(send(redirect_path, @case_log))
        end
      else
        redirect_path = "case_log_#{@page.id}_path"
        session[:errors] = @case_log.errors.to_json
        redirect_to(send(redirect_path, @case_log))
      end
    else
      render_not_found
    end
  end

  def check_answers
    if @case_log
      current_url = request.env["PATH_INFO"]
      subsection = @case_log.form.get_subsection(current_url.split("/")[-2])
      render "form/check_answers", locals: { subsection: }
    else
      render_not_found
    end
  end

  def review
    if @case_log
      render "form/review"
    else
      render_not_found
    end
  end

  FormHandler.instance.forms.each do |_key, form|
    form.pages.map do |page|
      define_method(page.id) do |_errors = {}|
        if @case_log
          if session["errors"]
            JSON(session["errors"]).each do |field, messages|
              messages.each { |message| @case_log.errors.add field.to_sym, message }
            end
          end
          @subsection = @case_log.form.subsection_for_page(page)
          @page = @case_log.form.get_page(page.id)
          if @page.routed_to?(@case_log) && @page.subsection.enabled?(@case_log)
            render "form/page"
          else
            redirect_to case_log_path(@case_log)
          end
        else
          render_not_found
        end
      end
    end
  end

private

  def responses_for_page(page)
    page.questions.each_with_object({}) do |question, result|
      question_params = params["case_log"][question.id]
      if question.type == "date"
        day = params["case_log"]["#{question.id}(3i)"]
        month = params["case_log"]["#{question.id}(2i)"]
        year = params["case_log"]["#{question.id}(1i)"]
        next unless [day, month, year].any?(&:present?)

        result[question.id] = if day.to_i.between?(1, 31) && month.to_i.between?(1, 12) && year.to_i.between?(2000, 2200)
                                Date.new(year.to_i, month.to_i, day.to_i)
                              else
                                Date.new(0, 1, 1)
                              end
      end
      next unless question_params

      if %w[checkbox validation_override].include?(question.type)
        question.answer_options.keys.reject { |x| x.match(/divider/) }.each do |option|
          result[option] = question_params.include?(option) ? 1 : 0
        end
      else
        result[question.id] = question_params
      end
      result
    end
  end

  def find_resource
    @case_log = current_user.case_logs.find_by(id: params[:id])
  end

  def find_resource_by_named_id
    @case_log = current_user.case_logs.find_by(id: params[:case_log_id])
  end

  def is_referrer_check_answers?
    referrer = request.headers["HTTP_REFERER"].presence || ""
    referrer.present? && CGI.parse(referrer.split("?")[-1]).present? && CGI.parse(referrer.split("?")[-1])["referrer"][0] == "check_answers"
  end
end
