require 'spec_helper'

RSpec.feature 'Admin Transaction Sync Batches', js: true do
  stub_authorization!

  background do
    create :store, default: true
  end

  let!(:transaction_sync_batch) { create :transaction_sync_batch }
  let!(:second_transaction_sync_batch) { create :transaction_sync_batch, :with_logs }
  let!(:processing_transaction_sync_log) { create :transaction_sync_log, transaction_sync_batch: transaction_sync_batch }
  let!(:success_transaction_sync_log) { create :transaction_sync_log, :success, transaction_sync_batch: transaction_sync_batch }
  
  scenario "renders transaction backfill index" do
    visit spree.admin_transaction_sync_batches_path(per_page: 1)

    within "#transaction_sync_batches" do
      expect(page).to have_content(transaction_sync_batch.id)
      expect(page).to have_content(transaction_sync_batch.created_at)
      expect(page).to have_content(transaction_sync_batch.updated_at)

      within "tbody td:nth-child(4)" do
        expect(page).to have_content("1/2")
      end

      within "tbody td:nth-child(5)" do
        expect(page).to have_content("Processing")
      end
    end

    within ".pagination" do
      click_on "Next"
    end

    within "#transaction_sync_batches" do
      expect(page).to have_content(second_transaction_sync_batch.id)
      expect(page).to have_content(second_transaction_sync_batch.created_at)
      expect(page).to have_content(second_transaction_sync_batch.updated_at)

      within "tbody td:nth-child(4)" do
        expect(page).to have_content("0/1")
      end

      within "tbody td:nth-child(5)" do
        expect(page).to have_content("Processing")
      end
    end

    within ".pagination" do
      click_on "Prev"
    end

    within ".actions" do
      find(".fa-edit").click
    end

    within "#transaction_sync_batch_logs" do
      within "tbody tr:first-child" do
        within "td:first-child" do
          expect(page).to have_content(processing_transaction_sync_log.id)
        end

        within "td:nth-child(2)" do
          expect(page).to have_content(processing_transaction_sync_log.order.number)
        end
        
        within "td:nth-child(3)" do
          expect(page).to have_content("-")
        end

        within "td:nth-child(4)" do
          expect(page).to have_content("Processing")
        end

        expect(page).to have_content(processing_transaction_sync_log.created_at)
        expect(page).to have_content(processing_transaction_sync_log.updated_at)
      end

      within "tbody tr:nth-child(2)" do
        within "td:first-child" do
          expect(page).to have_content(success_transaction_sync_log.id)
        end

        within "td:nth-child(2)" do
          expect(page).to have_content(success_transaction_sync_log.order.number)
        end

        within "td:nth-child(3)" do
          expect(page).to have_content(success_transaction_sync_log.order_transaction.transaction_id)
        end

        within "td:nth-child(4)" do
          expect(page).to have_content("Success")
        end

        expect(page).to have_content(success_transaction_sync_log.created_at)
        expect(page).to have_content(success_transaction_sync_log.updated_at)
      end
    end
  end
end