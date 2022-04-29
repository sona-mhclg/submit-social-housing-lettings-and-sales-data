class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :two_factor_authenticatable

  belongs_to :organisation
  has_many :owned_case_logs, through: :organisation
  has_many :managed_case_logs, through: :organisation

  has_paper_trail ignore: %w[last_sign_in_at
                             current_sign_in_at
                             current_sign_in_ip
                             last_sign_in_ip
                             failed_attempts
                             unlock_token
                             locked_at
                             reset_password_token
                             reset_password_sent_at
                             remember_created_at
                             sign_in_count
                             updated_at]

  has_one_time_password(encrypted: true)

  ROLES = {
    data_accessor: 0,
    data_provider: 1,
    data_coordinator: 2,
    support: 99,
  }.freeze

  enum role: ROLES

  def case_logs
    if support?
      CaseLog.all
    else
      CaseLog.filter_by_organisation(organisation)
    end
  end

  def completed_case_logs
    case_logs.completed
  end

  def not_completed_case_logs
    case_logs.not_completed
  end

  def is_key_contact?
    is_key_contact
  end

  def is_key_contact!
    update(is_key_contact: true)
  end

  def is_data_protection_officer?
    is_dpo
  end

  def is_data_protection_officer!
    update!(is_dpo: true)
  end

  MFA_TEMPLATE_ID = "6bdf5ee1-8e01-4be1-b1f9-747061d8a24c".freeze
  RESET_PASSWORD_TEMPLATE_ID = "2c410c19-80a7-481c-a531-2bcb3264f8e6".freeze
  SET_PASSWORD_TEMPLATE_ID   = "257460a6-6616-4640-a3f9-17c3d73d9e91".freeze

  def reset_password_notify_template
    last_sign_in_at ? RESET_PASSWORD_TEMPLATE_ID : SET_PASSWORD_TEMPLATE_ID
  end

  def need_two_factor_authentication?(_request)
    support?
  end

  def send_two_factor_authentication_code(code)
    template_id = MFA_TEMPLATE_ID
    personalisation = { otp: code }
    DeviseNotifyMailer.new.send_email(email, template_id, personalisation)
  end

  def assignable_roles
    return {} unless data_coordinator? || support?
    return ROLES if support?

    ROLES.except(:support)
  end

  def case_logs_filters
    if support?
      %i[status years user organisation]
    else
      %i[status years user]
    end
  end
end
