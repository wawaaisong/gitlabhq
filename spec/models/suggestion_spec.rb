# frozen_string_literal: true

require 'spec_helper'

describe Suggestion do
  let(:suggestion) { create(:suggestion) }

  describe 'associations' do
    it { is_expected.to belong_to(:note) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:note) }

    context 'when suggestion is applied' do
      before do
        allow(subject).to receive(:applied?).and_return(true)
      end

      it { is_expected.to validate_presence_of(:commit_id) }
    end
  end

  describe '#appliable?' do
    context 'when note does not support suggestions' do
      it 'returns false' do
        expect_next_instance_of(DiffNote) do |note|
          allow(note).to receive(:supports_suggestion?) { false }
        end

        expect(suggestion).not_to be_appliable
      end
    end

    context 'when patch is already applied' do
      let(:suggestion) { create(:suggestion, :applied) }

      it 'returns false' do
        expect(suggestion).not_to be_appliable
      end
    end

    context 'when merge request is not opened' do
      let(:merge_request) { create(:merge_request, :merged) }
      let(:note) do
        create(:diff_note_on_merge_request, project: merge_request.project,
                                            noteable: merge_request)
      end

      let(:suggestion) { create(:suggestion, note: note) }

      it 'returns false' do
        expect(suggestion).not_to be_appliable
      end
    end
  end
end
