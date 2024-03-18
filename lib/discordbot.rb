require 'discorb'
require 'dotenv'


localizations = {
  info: {
    title: {
      en: "%s's info",
      ja: "%sの詳細"
    },
    fields: {
      en: ["Name", "ID", "Bot", "Joined at", "Account created at"],
      ja: %w[名前 ID ボット 参加日時 アカウント作成日時]
    },
    yn: {
      en: %w[Yes No],
      ja: %w[はい いいえ]
    }
  }
}

Dotenv.load


intents = Discorb::Intents.new
intents.message_content = true
intents.members = true

client = Discorb::Client.new(intents: intents)

client.once :standby do
  puts "Logged in as #{client.user}"
end

def convert_role(guild, string)
  guild.roles.find do |role|
    role.id == string || role.name == string || role.mention == string
  end
end

client.on :reaction_add do |event|
  next unless event.guild
  next unless event.member
  unless event.emoji.value.end_with?(
    0x0000fe0f.chr('utf-8') + 0x000020e3.chr('utf-8')
  )
    next
  end
  next if event.member.bot?

  msg = event.fetch_message.wait
  if msg.embeds.length.positive? && msg.embeds[0].title == 'Role panel' &&
     msg.author == client.user
    role_ids = msg.embeds[0].description.scan(/(?<=<@&)\d+(?=>)/)

    role = event.guild.roles[role_ids[event.emoji.value[0].to_i - 1]]
    next if role.nil?

    event.member.add_role(role)
  end
end

client.on :reaction_remove do |event|
  unless event.emoji.value.end_with?(
    0x0000fe0f.chr('utf-8') + 0x000020e3.chr('utf-8')
  )
    next
  end
  next unless event.member
  next if event.member.bot?

  msg = event.fetch_message.wait
  if msg.embeds.length.positive? && msg.embeds[0].title == 'Role panel' &&
     msg.author == client.user
    role_ids = msg.embeds[0].description.scan(/(?<=<@&)\d+(?=>)/)

    role = event.guild.roles[role_ids[event.emoji.value[0].to_i - 1]]
    next if role.nil?

    event.member.remove_role(role)
  end
end

client.on :message do |message|
  next unless message.content.start_with?('sudo rp')
  next if message.author.bot?

  message.reply('Too many roles.') if message.content.split.length > 10
  roles =
    message
      .content
      .delete_prefix('sudo rp ')
      .split
      .map
      .with_index do |raw_role, index|
      [index, convert_role(message.guild, raw_role), raw_role]
    end
  if (convert_fails = roles.filter { |r| r[1].nil? }).length.positive?
    message.reply("#{convert_fails.map { |r| r[2] }.join(", ")} is not a role.")
    next
  end
  rp_msg =
    message
      .channel
      .post(
        embed:
          Discorb::Embed.new(
            'Reaction Roles',
            roles
              .map
              .with_index(1) do |r, index|
              "#{index}\ufe0f\u20e3#{r[1].mention}"
            end
              .join("\n")
          )
      )
      .wait
  1
    .upto(roles.length)
    .each do |i|
    rp_msg.add_reaction(Discorb::UnicodeEmoji["#{i}\ufe0f\u20e3"]).wait
  end
end


client.user_command({ default: "info", ja: "詳細" }) do |interaction, user|
  field_name =
    localizations[:info][:fields][interaction.locale] ||
      localizations[:info][:fields][:en]
  interaction.post(
    embed:
      Discorb::Embed.new(
        format(
          (
            localizations[:info][:title][interaction.locale] ||
              localizations[:info][:title][:en]
          ),
          user.to_s
        ),
        fields: [
          Discorb::Embed::Field.new(field_name[0], user.to_s),
          Discorb::Embed::Field.new(field_name[1], user.id),
          Discorb::Embed::Field.new(
            field_name[2],
            (
              localizations[:info][:yn][locale] ||
                localizations[:info][:yn][:en]
            )[
              user.bot? ? 0 : 1
            ]
          ),
          Discorb::Embed::Field.new(field_name[3], user.joined_at.to_df("F")),
          Discorb::Embed::Field.new(field_name[4], user.created_at.to_df("F"))
        ],
        thumbnail: user.avatar&.url
      ),
    ephemeral: true
  )
end

client.change_presence(
  Discorb::Activity.new("playing with cute bottoms", :streaming, "https://youtube.com/watch?v=5j8aG_zO9DI&pp=ygUYY3V0ZSBmZW1ib3lzIGNvbXBpbGF0aW9u")
)

client.run(ENV['TOKEN'])
