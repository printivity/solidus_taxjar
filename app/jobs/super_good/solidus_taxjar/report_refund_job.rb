# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    class ReportRefundJob < ApplicationJob
      queue_as { SuperGood::SolidusTaxjar.job_queue }

      def perform(reimbursement)
        SuperGood::SolidusTaxjar.reporting.create_refund(reimbursement)
      end
    end
  end
end
