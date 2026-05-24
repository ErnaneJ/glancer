# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::ARSanitizer do
  describe ".ensure_safe!" do
    context "with safe read-only expressions" do
      it "passes User.all" do
        expect { described_class.ensure_safe!("User.all") }.not_to raise_error
      end

      it "passes a where chain" do
        expect { described_class.ensure_safe!("User.where(active: true).count") }.not_to raise_error
      end

      it "passes joins + select" do
        code = "Order.joins(:items).select('orders.id, count(items.id) as item_count').group('orders.id')"
        expect { described_class.ensure_safe!(code) }.not_to raise_error
      end

      it "passes pluck" do
        expect { described_class.ensure_safe!("User.pluck(:email)") }.not_to raise_error
      end

      it "passes aggregate methods" do
        expect { described_class.ensure_safe!("Order.sum(:total)") }.not_to raise_error
        expect { described_class.ensure_safe!("Order.average(:amount)") }.not_to raise_error
        expect { described_class.ensure_safe!("Order.minimum(:created_at)") }.not_to raise_error
      end

      it "does not block .update_at (column-like word in a scope)" do
        # .updated_at is a column accessor, not the .update write method
        expect { described_class.ensure_safe!("User.order(:updated_at)") }.not_to raise_error
      end

      it "does not block .created_at" do
        expect { described_class.ensure_safe!("User.where('created_at > ?', 1.week.ago)") }.not_to raise_error
      end
    end

    context "with destructive ActiveRecord methods" do
      it "blocks .destroy" do
        expect { described_class.ensure_safe!("User.first.destroy") }
          .to raise_error(Glancer::Error, /destroy/)
      end

      it "blocks .destroy_all" do
        expect { described_class.ensure_safe!("User.where(active: false).destroy_all") }
          .to raise_error(Glancer::Error, /destroy/)
      end

      it "blocks .delete" do
        expect { described_class.ensure_safe!("User.first.delete") }
          .to raise_error(Glancer::Error, /delete/)
      end

      it "blocks .delete_all" do
        expect { described_class.ensure_safe!("User.delete_all") }
          .to raise_error(Glancer::Error, /delete/)
      end

      it "blocks .update (write form)" do
        expect { described_class.ensure_safe!("User.first.update(name: 'x')") }
          .to raise_error(Glancer::Error, /update/)
      end

      it "blocks .update! (bang form)" do
        expect { described_class.ensure_safe!("User.first.update!(name: 'x')") }
          .to raise_error(Glancer::Error, /update/)
      end

      it "blocks .update_all" do
        expect { described_class.ensure_safe!("User.update_all(active: false)") }
          .to raise_error(Glancer::Error, /update_all/)
      end

      it "blocks .save" do
        expect { described_class.ensure_safe!("u = User.first; u.name = 'x'; u.save") }
          .to raise_error(Glancer::Error, /save/)
      end

      it "blocks .save!" do
        expect { described_class.ensure_safe!("User.first.save!") }
          .to raise_error(Glancer::Error, /save/)
      end

      it "blocks .create" do
        expect { described_class.ensure_safe!("User.create(name: 'Eve')") }
          .to raise_error(Glancer::Error, /create/)
      end

      it "blocks .create!" do
        expect { described_class.ensure_safe!("User.create!(name: 'Eve')") }
          .to raise_error(Glancer::Error, /create/)
      end

      it "blocks .insert" do
        expect { described_class.ensure_safe!("User.insert(name: 'Eve')") }
          .to raise_error(Glancer::Error, /insert/)
      end

      it "blocks .upsert" do
        expect { described_class.ensure_safe!("User.upsert(id: 1, name: 'Eve')") }
          .to raise_error(Glancer::Error, /upsert/)
      end

      it "blocks .touch" do
        expect { described_class.ensure_safe!("User.first.touch") }
          .to raise_error(Glancer::Error, /touch/)
      end
    end

    context "with shell / OS execution" do
      it "blocks backtick shell execution" do
        expect { described_class.ensure_safe!("`ls -la`") }
          .to raise_error(Glancer::Error, /shell/)
      end

      it "blocks system() call" do
        expect { described_class.ensure_safe!("system('rm -rf /')") }
          .to raise_error(Glancer::Error, /shell/)
      end

      it "blocks exec()" do
        expect { described_class.ensure_safe!("exec('cat /etc/passwd')") }
          .to raise_error(Glancer::Error, /shell/)
      end
    end

    context "with eval" do
      it "blocks eval()" do
        expect { described_class.ensure_safe!("eval('User.where(1=1)')") }
          .to raise_error(Glancer::Error, /eval/)
      end

      it "blocks instance_eval" do
        expect { described_class.ensure_safe!("User.instance_eval { delete_all }") }
          .to raise_error(Glancer::Error, /eval/)
      end
    end

    context "with file writes" do
      it "blocks FileUtils" do
        expect { described_class.ensure_safe!("FileUtils.rm_rf('/')") }
          .to raise_error(Glancer::Error, /file write/)
      end

      it "blocks File.write" do
        expect { described_class.ensure_safe!("File.write('/etc/hosts', 'evil')") }
          .to raise_error(Glancer::Error, /file write/)
      end
    end

    context "with dynamic loading" do
      it "blocks require" do
        expect { described_class.ensure_safe!("require 'open3'") }
          .to raise_error(Glancer::Error, /load/)
      end

      it "blocks load" do
        expect { described_class.ensure_safe!("load '/evil.rb'") }
          .to raise_error(Glancer::Error, /load/)
      end
    end

    context "when an unexpected StandardError occurs during sanitization" do
      it "wraps the error in Glancer::Error" do
        allow(described_class).to receive(:ensure_safe!).and_call_original
        allow_any_instance_of(String).to receive(:match?).and_raise(StandardError, "regex engine failure")
        expect { described_class.ensure_safe!("User.count") }
          .to raise_error(Glancer::Error, /AR sanitization failed/)
      end
    end
  end
end
