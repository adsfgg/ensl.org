require "spec_helper"

describe Api::V1::UsersCollection do
  let(:collection) { Api::V1::UsersCollection.new }

  describe "#execute_query" do
    describe "when there are users with no teams" do
      before do
        3.times { create(:user) }
      end

      it "returns 3 results" do
        expect(collection.execute_query.size).to eq(3)
      end
    end

    describe "when there are some users with teams" do
      before do
        3.times { create(:user_with_team) }
      end

      it "returns 3 results" do
        expect(collection.execute_query.size).to eq(3)
      end

      it "returns 6 columns" do
        expect(collection.execute_query.first.size).to eq(6)
      end
    end
  end
end
