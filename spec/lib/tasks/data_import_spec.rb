require "rails_helper"
require "rake"

describe "rake core:data_import", type: :task do
  subject(:task) { Rake::Task["core:data_import"] }

  let(:fixture_path) { "spec/fixtures/softwire_imports/organisations" }
  let(:instance_name) { "paas_import_instance" }
  let(:type) { "organisation" }

  let(:storage_service) { instance_double(StorageService) }
  let(:paas_config_service) { instance_double(PaasConfigurationService) }
  let(:import_service) { instance_double(Imports::OrganisationImportService) }

  before do
    Rake.application.rake_require("tasks/data_import")
    Rake::Task.define_task(:environment)
    task.reenable

    allow(StorageService).to receive(:new).and_return(storage_service)
    allow(PaasConfigurationService).to receive(:new).and_return(paas_config_service)
    allow(ENV).to receive(:[])
    allow(ENV).to receive(:[]).with("IMPORT_PAAS_INSTANCE").and_return(instance_name)
  end

  context "when importing organisation data" do
    before do
      allow(Imports::OrganisationImportService).to receive(:new).and_return(import_service)
    end

    it "creates an organisation from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::OrganisationImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_organisations).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  context "when importing user data" do
    let(:type) { "user" }
    let(:import_service) { instance_double(Imports::UserImportService) }

    before do
      allow(Imports::UserImportService).to receive(:new).and_return(import_service)
    end

    it "creates a user from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::UserImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_users).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  context "when importing data protection confirmation data" do
    let(:type) { "data-protection-confirmation" }
    let(:import_service) { instance_double(Imports::DataProtectionConfirmationImportService) }
    let(:fixture_path) { "spec/fixtures/softwire_imports/data_protection_confirmations" }

    before do
      allow(Imports::DataProtectionConfirmationImportService).to receive(:new).and_return(import_service)
    end

    it "creates an organisation from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::DataProtectionConfirmationImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_data_protection_confirmations).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  context "when importing organisation local authority data" do
    let(:type) { "organisation-las" }
    let(:import_service) { instance_double(Imports::OrganisationLaImportService) }
    let(:fixture_path) { "spec/fixtures/softwire_imports/organisation_las" }

    before do
      allow(Imports::OrganisationLaImportService).to receive(:new).and_return(import_service)
    end

    it "creates an organisation la from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::OrganisationLaImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_organisation_las).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  context "when importing organisation rent period data" do
    let(:type) { "organisation-rent-periods" }
    let(:import_service) { instance_double(Imports::OrganisationRentPeriodImportService) }
    let(:fixture_path) { "spec/fixtures/softwire_imports/organisation_rent_periods" }

    before do
      allow(Imports::OrganisationRentPeriodImportService).to receive(:new).and_return(import_service)
    end

    it "creates an organisation la from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::OrganisationRentPeriodImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_organisation_rent_periods).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  context "when importing case logs" do
    let(:type) { "case-logs" }
    let(:import_service) { instance_double(Imports::CaseLogsImportService) }
    let(:fixture_path) { "spec/fixtures/softwire_imports/case_logs" }

    before do
      allow(Imports::CaseLogsImportService).to receive(:new).and_return(import_service)
    end

    it "creates case logs from the given XML file" do
      expect(StorageService).to receive(:new).with(paas_config_service, instance_name)
      expect(Imports::CaseLogsImportService).to receive(:new).with(storage_service)
      expect(import_service).to receive(:create_logs).with(fixture_path)

      task.invoke(type, fixture_path)
    end
  end

  it "raises an exception if no parameters are provided" do
    expect { task.invoke }.to raise_error(/Usage/)
  end

  it "raises an exception if a single parameter is provided" do
    expect { task.invoke("one_parameter") }.to raise_error(/Usage/)
  end

  it "raises an exception if the type is not supported" do
    expect { task.invoke("unknown_type", "my_path") }.to raise_error(/Type unknown_type is not supported/)
  end
end
