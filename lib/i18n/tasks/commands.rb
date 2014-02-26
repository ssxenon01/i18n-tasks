require 'i18n/tasks/commands_base'
require 'i18n/tasks/reports/terminal'
require 'i18n/tasks/reports/spreadsheet'

module I18n::Tasks
  class Commands < CommandsBase
    include Term::ANSIColor
    require 'highline/import'

    desc 'show missing translations'
    cmd :missing do |opt = {}|
      opt[:locales] = locales_opt(opt[:locales])
      terminal_report.missing_keys i18n_task.missing_keys(opt)
    end

    desc 'show unused translations'
    cmd :unused do
      terminal_report.unused_keys
    end

    desc 'add missing keys to the base locale (default value: key.humanize)'
    cmd :fill_base do |opt = {}|
      opt[:value] ||= lambda { |key| key.split('.').last.to_s.humanize }
      fill from: :value, value: opt[:value], locale: base_locale
    end

    desc 'remove unused keys'
    cmd :remove_unused do |opt = {}|
      locales = locales_opt opt[:locales]
      unused_keys = i18n_task.unused_keys
      if unused_keys.present?
        terminal_report.unused_keys(unused_keys)
        unless ENV['CONFIRM']
          exit 1 unless agree(red "All these translations will be removed in #{bold locales * ', '}#{red '.'} " + yellow('Continue? (yes/no)') + ' ')
        end
        i18n_task.remove_unused!(locales)
        $stderr.puts "Removed #{unused_keys.size} keys"
      else
        $stderr.puts bold green 'No unused keys to remove'
      end
    end

    desc 'show where the keys are used in the code'
    cmd :usages do |opt = {}|
      filter = opt[:filter] ? opt[:filter].tr('+', ',') : nil
      used_keys = i18n_task.scanner.with_key_filter(filter) {
        i18n_task.used_keys true
      }
      terminal_report.used_keys used_keys
    end

    desc 'normalize translation data: sort and move to the right files'
    cmd :normalize do |opt = {}|
      i18n_task.normalize_store! locales_opt(opt[:locales])
    end

    desc 'fill missing translations with values'
    cmd :fill do |opt = {}|
      opt[:locales] = locales_opt(opt[:locales])
      i18n_task.send :"fill_with_#{opt.delete(:from)}!", opt
    end

    desc 'display i18n-tasks configuration'
    cmd :config do
      puts i18n_task.config_for_inspect.to_yaml.sub(/\A---\n/, '').gsub('!ruby/hash:ActiveSupport::HashWithIndifferentAccess', '')
    end

    desc 'save missing and unused translations to an Excel file'
    cmd :save_spreadsheet do |opt = {}|
      begin
        require 'axlsx'
      rescue LoadError
        message = %Q(For spreadsheet report please add axlsx gem to Gemfile:\ngem 'axlsx', '~> 2.0')
        STDERR.puts Term::ANSIColor.red Term::ANSIColor.bold message
        exit 1
      end
      spreadsheet_report.save_report opt[:path]
    end

    protected

    def terminal_report
      @terminal_report ||= I18n::Tasks::Reports::Terminal.new(i18n_task)
    end

    def spreadsheet_report
      @spreadsheet_report ||= I18n::Tasks::Reports::Spreadsheet.new(i18n_task)
    end
  end
end
