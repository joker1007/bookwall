# frozen_string_literal: true

require "rails_helper"

RSpec.describe Library, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to have_many(:series).dependent(:destroy) }
    it { is_expected.to have_many(:books).dependent(:destroy) }
    it { is_expected.to have_many(:scan_logs).dependent(:destroy) }
    it { is_expected.to have_many(:library_shares).dependent(:destroy) }
    it { is_expected.to have_many(:shared_users).through(:library_shares) }
  end

  describe "validations" do
    subject { build(:library) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_uniqueness_of(:path) }
  end

  describe "visibility" do
    let(:owner) { create(:user) }
    let(:shared) { create(:user) }
    let(:stranger) { create(:user) }
    let!(:library) { create(:library, owner: owner) }

    before { create(:library_share, library: library, user: shared) }

    describe ".accessible_by" do
      it "includes owned libraries" do
        expect(Library.accessible_by(owner)).to contain_exactly(library)
      end

      it "includes shared libraries" do
        expect(Library.accessible_by(shared)).to contain_exactly(library)
      end

      it "excludes libraries the user neither owns nor is shared" do
        expect(Library.accessible_by(stranger)).to be_empty
      end

      it "does not duplicate a library shared back to its owner" do
        create(:library_share, library: library, user: owner)
        expect(Library.accessible_by(owner).to_a).to contain_exactly(library)
      end
    end

    describe ".owned_by" do
      it "returns only owned libraries" do
        expect(Library.owned_by(owner)).to contain_exactly(library)
        expect(Library.owned_by(shared)).to be_empty
      end
    end

    describe "#can_manage?" do
      it "is true only for the owner" do
        expect(library.can_manage?(owner)).to be(true)
        expect(library.can_manage?(shared)).to be(false)
      end
    end
  end
end
