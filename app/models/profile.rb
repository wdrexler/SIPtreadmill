class Profile < ActiveRecord::Base
  classy_enum_attr :transport_type, default: 'u1'
  attr_accessible :calls_per_second, :max_calls, :max_concurrent, :name, :transport_type
  attr_accessible :use_time, :duration
  belongs_to :user
  has_many :test_runs

  validates_presence_of :name, :calls_per_second, :max_concurrent, :transport_type
  validates_uniqueness_of :name, scope: :user_id
  validate :check_end_condition

  def check_end_condition
    unless max_calls.present? || use_time
      errors.add :max_calls, "Must either specify max calls or a test duration"
    end

    if use_time && (!duration.present? || duration <= 0)
      errors.add :duration, "Must specify a test duration"
    end
  end

  def writable?
    self.test_runs.count == 0
  end

  def duplicate(requesting_user)
    new_profile_opts = { name: "#{self.name} (Copy)",
                         calls_per_second: self.calls_per_second,
                         max_calls: self.max_calls,
                         max_concurrent: self.max_concurrent,
                         transport_type: self.transport_type
                       }
    new_profile = Profile.create new_profile_opts
    new_profile.user = requesting_user
    new_profile.save ? new_profile : nil
  end
end
