module Validations::FinancialValidations
  include Validations::SharedValidations
  # Validations methods need to be called 'validate_<page_name>' to run on model save
  # or 'validate_' to run on submit as well
  def validate_outstanding_rent_amount(record)
    if !record.has_hbrentshortfall? && record.tshortfall.present?
      record.errors.add :tshortfall, I18n.t("validations.financial.tshortfall.outstanding_amount_not_required")
    end
  end

  EMPLOYED_STATUSES = [1, 0].freeze
  def validate_net_income_uc_proportion(record)
    (1..8).any? do |n|
      economic_status = record["ecstat#{n}"]
      is_employed = EMPLOYED_STATUSES.include?(economic_status)
      relationship = record["relat#{n}"]
      is_partner_or_main = relationship == "P" || (relationship.nil? && economic_status.present?)
      if is_employed && is_partner_or_main && record.benefits&.zero?
        record.errors.add :benefits, I18n.t("validations.financial.benefits.part_or_full_time")
      end
    end
  end

  def validate_net_income(record)
    if record.ecstat1 && record.weekly_net_income
      if record.weekly_net_income > record.applicable_income_range.hard_max
        record.errors.add :earnings, I18n.t("validations.financial.earnings.over_hard_max", hard_max: record.applicable_income_range.hard_max)
      end

      if record.weekly_net_income < record.applicable_income_range.hard_min
        record.errors.add :earnings, I18n.t("validations.financial.earnings.under_hard_min", hard_min: record.applicable_income_range.hard_min)
      end
    end

    if record.earnings.present? && record.incfreq.blank?
      record.errors.add :incfreq, I18n.t("validations.financial.earnings.freq_missing")
    end

    if record.incfreq.present? && record.earnings.blank?
      record.errors.add :earnings, I18n.t("validations.financial.earnings.earnings_missing")
    end
  end

  def validate_negative_currency(record)
    t = %w[earnings brent scharge pscharge supcharg]
    t.each do |x|
      if record[x].present? && record[x].negative?
        record.errors.add x.to_sym, I18n.t("validations.financial.negative_currency")
      end
    end
  end

  def validate_tshortfall(record)
    if record.has_hbrentshortfall? &&
        (record.benefits_unknown? ||
          record.receives_no_benefits? ||
            record.receives_universal_credit_but_no_housing_benefit?)
      record.errors.add :tshortfall, I18n.t("validations.financial.hbrentshortfall.outstanding_no_benefits")
    end
  end

  def validate_rent_amount(record)
    if record.brent.present? && record.tshortfall.present? && record.brent < record.tshortfall * 2
      record.errors.add :brent, I18n.t("validations.financial.rent.less_than_double_shortfall", tshortfall: record.tshortfall * 2)
      record.errors.add :tshortfall, I18n.t("validations.financial.tshortfall.more_than_rent")
    end

    if record.tcharge.present? && weekly_value_in_range(record, "tcharge", 0, 9.99)
      record.errors.add :tcharge, I18n.t("validations.financial.tcharge.under_10")
    end

    answered_questions = [record.tcharge, record.chcharge].concat(record.household_charge && record.household_charge.zero? ? [record.household_charge] : [])
    if answered_questions.count(&:present?) > 1
      record.errors.add :tcharge, I18n.t("validations.financial.charges.complete_1_of_3") if record.tcharge.present?
      record.errors.add :chcharge, I18n.t("validations.financial.charges.complete_1_of_3") if record.chcharge.present?
      record.errors.add :household_charge, I18n.t("validations.financial.charges.complete_1_of_3") if record.household_charge.present?
    end

    validate_charges(record)
    validate_rent_range(record)
  end

private

  CHARGE_MAXIMUMS = {
    scharge: {
      "LA": {
        general_needs: 55,
        supported_housing: 280,
      },
      "PRP": {
        general_needs: 45,
        supported_housing: 165,
      },
    },
    pscharge: {
      "LA": {
        general_needs: 30,
        supported_housing: 200,
      },
      "PRP": {
        general_needs: 35,
        supported_housing: 75,
      },
    },
    supcharg: {
      "LA": {
        general_needs: 40,
        supported_housing: 465,
      },
      "PRP": {
        general_needs: 60,
        supported_housing: 120,
      },
    },
  }.freeze

  LANDLORD_VALUES = { :LA => :this_landlord, :PRP => :other_landlord }.freeze
  NEEDSTYPE_VALUES = { 0 => :supported_housing, 1 => :general_needs }.freeze

  def validate_charges(record)
    %i[scharge pscharge supcharg].each do |charge|
      maximum = CHARGE_MAXIMUMS.dig(charge, record.landlord.to_sym, NEEDSTYPE_VALUES[record.needstype])

      if maximum.present? && record[charge].present? && !weekly_value_in_range(record, charge, 0, maximum)
        record.errors.add charge, I18n.t("validations.financial.rent.#{charge}.#{LANDLORD_VALUES[record.landlord.to_sym]}.#{NEEDSTYPE_VALUES[record.needstype]}")
      end
      # binding.pry
    end
  end

  def weekly_value_in_range(record, field, min, max)
    record[field].present? && record.weekly_value(record[field]).present? && record.weekly_value(record[field]).between?(min, max)
  end

  def validate_rent_range(record)
    return if record.startdate.blank?

    collection_year = record.collection_start_year
    rent_range = LaRentRange.find_by(start_year: collection_year, la: record.la, beds: record.beds, lettype: record.lettype)

    if rent_range.present? && !weekly_value_in_range(record, "brent", rent_range.hard_min, rent_range.hard_max) && record.brent.present?
      record.errors.add :brent, I18n.t("validations.financial.brent.not_in_range")
      record.errors.add :beds, I18n.t("validations.financial.brent.beds.not_in_range")
      record.errors.add :la, I18n.t("validations.financial.brent.la.not_in_range")
      record.errors.add :rent_type, I18n.t("validations.financial.brent.rent_type.not_in_range")
      record.errors.add :needstype, I18n.t("validations.financial.brent.needstype.not_in_range")
    end
  end
end
