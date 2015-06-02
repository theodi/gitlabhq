require 'spec_helper'

describe API::API, api: true  do
  include ApiHelpers
  let(:admin) { create(:admin) }
  let!(:group1) { create(:group) }
  let!(:group2) { create(:group) }

  describe "GET /namespaces" do
    context "when unauthenticated" do
      it "should return authentication error" do
        get api("/namespaces")
        expect(response.status).to eq(401)
      end
    end

    context "when authenticated as  admin" do
      it "admin: should return an array of all namespaces" do
        get api("/namespaces", admin)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array

        expect(json_response.length).to eq(Namespace.count)
      end
    end
  end
end
