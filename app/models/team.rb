# == Schema Information
#
# Table name: teams
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  irc        :string(255)
#  web        :string(255)
#  tag        :string(255)
#  country    :string(255)
#  comment    :string(255)
#  created_at :datetime
#  updated_at :datetime
#  logo       :string(255)
#  founder_id :integer
#  active     :boolean          default(TRUE), not null
#  recruiting :string(255)
#

class Team < ActiveRecord::Base
  include Extra

  LOGOS = "logos"
  STATUS_INACTIVE = 0
  STATUS_ACTIVE = 1

  attr_protected :id, :active, :founder_id, :created_at, :updated_at

  validates_presence_of :name, :tag
  validates_length_of :name, :tag, :in => 2..20
  validates_length_of :irc, :maximum => 20, :allow_blank => true
  validates_length_of :web, :maximum => 50, :allow_blank => true
  validates_format_of :country, :with => /\A[A-Z]{2}\z$/, :allow_blank => true
  validates_length_of [:comment, :recruiting], :in => 0..75, :allow_blank => true

  scope :with_teamers_num,
    lambda { |num| {
    :select => "teams.*, COUNT(T.id) AS teamers_num",
    :joins	=> "LEFT JOIN teamers T ON T.team_id = teams.id AND T.rank >= #{Teamer::RANK_MEMBER}",
    :group => "teams.id",
    :having => ["teamers_num >= ?", num]} }
  scope :with_teamers, :include => :teamers
  scope :active, :conditions => {:active => true}
  scope :inactive, :conditions => {:active => false}
  scope :ordered, :order => "name"
  scope :recruiting, :conditions => "recruiting IS NOT NULL AND recruiting != ''"

  belongs_to :founder, :class_name => "User"
  has_many :teamers, :dependent => :destroy
  has_many :leaders, :class_name => "Teamer", :conditions => ["rank = ?", Teamer::RANK_LEADER]
  has_many :contesters, :dependent => :destroy
  has_many :contests, :through => :contesters, :conditions => {"contesters.active" => true}
  has_many :received_messages, :class_name => "Message", :as => "recipient"
  has_many :sent_messages, :class_name => "Message", :as => "sender"
  has_many :matches, :through => :contesters
  has_many :matches_finished, :through => :contesters, :source => :matches, :conditions => "(score1 != 0 OR score2 != 0)"
  has_many :matches_won, :through => :contesters, :source => :matches,
    :conditions => "((score1 > score2 AND contester1_id = contesters.id) OR (score2 > score1 AND contester2_id = contesters.id)) AND (score1 != 0 OR score2 != 0)"
  has_many :matches_lost, :through => :contesters, :source => :matches,
    :conditions => "((score1 < score2 AND contester1_id = contesters.id) OR (score2 < score1 AND contester2_id = contesters.id)) AND (score1 != 0 OR score2 != 0)"
  has_many :matches_draw, :through => :contesters, :source => :matches,
    :conditions => "(score1 = score2 AND score1 > 0) AND (score1 != 0 OR score2 != 0)"

  mount_uploader :logo, TeamUploader

  before_create :init_variables
  after_create :add_leader

  def to_s
    name
  end

  def leaders_s
    leaders.join(", ")
  end

  def init_variables
    self.active = true
    self.recruiting = nil
  end

  def add_leader
    teamer = Teamer.new
    teamer.user = founder
    teamer.team = self
    teamer.rank = Teamer::RANK_LEADER
    teamer.save
    founder.update_attribute :team_id, self.id
  end

  def self.search(search)
    search ? where("LOWER(name) LIKE LOWER(?)", "%#{search}%") : scoped
  end

  def destroy
    if matches.count > 0
      update_attribute :active, false
      teamers.update_all ["rank = ?", Teamer::RANK_REMOVED]
    else
      super
    end
  end

  def recover
    update_attribute :active, true
  end

  def is_leader? user
    teamers.leaders.exists?(:user_id => user.id)
  end

  def can_create? cuser
    cuser and !cuser.banned?(Ban::TYPE_MUTE)
  end

  def can_update? cuser
    cuser and (is_leader? cuser or cuser.admin?)
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
