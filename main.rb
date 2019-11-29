require 'chingu'

$tileset = "block_donut"

class Game < Chingu::Window

	def initialize
		super(800,600,false)
		self.caption = "Tetris Showdown"
		self.input = {
			tab: :smash_p1,
			a: :move_left_p1,
			d: :move_right_p1,
			holding_s: :move_down_p1,
			w: :rotate_p1,
			q: :attack_p1_p1,
			e: :attack_p1_p2,
			right_ctrl: :smash_p2,
			left: :move_left_p2,
			right: :move_right_p2,
			holding_down: :move_down_p2,
			up: :rotate_p2,
			del: :attack_p2_p1,
			page_down: :attack_p2_p2
		}
		@background = Background.create
		@tetris_fields = []
		@tetris_fields_images = []
		@field_blocks = []
		@blocks = []
		@timers = []
		@down_timers = []
		@rows_waiting_for_removal = []
		@removal_animations = []
		@preview_blocks = []
		@first_blocks = []
		@current_block_numbers = []
		@next_block_types = []
		@player_attacks = []
		@attack_texts = []
		@attack_big_texts = []
		@current_shake_number = []
		@amount_of_players = 0
		@game_speed = 25
		@player2_is_computer = true
		@computer_goal_destination = []
		@computer_current_destination
		@position_calculated = false
		@ticks_needed_for_next_move = 20
		@current_computer_tick = 0
		new_game 2 # Skapa nytt spel med 2 spelare
	end
	def update
		super
		current_player = 0
		while current_player < @amount_of_players # Gör allt för varje spelare som finns
			@timers[current_player] += 1
			if @timers[current_player] > @game_speed #Timern för graviteten
				@timers[current_player] = 0
				end_fall = false
				@blocks[current_player].each do |block| #Kolla så att det inte finns nåt som blockerar nåt av blocken
					if block.grid_y == 21 || @tetris_fields[current_player][block.grid_y+1][block.grid_x] != 0
						end_fall = true # Avsluta fallet och träffa marken
					end
				end
				if end_fall == false
					@blocks[current_player].each do |block| # Flytta ner spelarens block
						block.y += 26
						block.grid_y += 1
					end
				else
					translate_blocks (current_player)
				end
			end
			# Uppdatera animationen om det behövs
			if @rows_waiting_for_removal[current_player].length != 0 then remove_rows_after_translation current_player
			end
			# Move down all attacks in the meters
			@player_attacks[current_player].each_with_index do |attack, i| 
				attack.fall_speed += 0.15
				attack.y += attack.fall_speed
				if attack.y >= 180 + (14-i)*26 + @current_shake_number[current_player] then attack.y = 180 + (14-i)*26 + @current_shake_number[current_player]
				end
			end
			current_player += 1
		end

		#Code for the TETRIS A.I
		if @player2_is_computer == true
			if @position_calculated == false #CALCULATE POSITION
				calculate_best_position
			elsif @blocks[0].length != 0
				# MOVEMENT
				@current_computer_tick += 0.6
				if @current_computer_tick > @ticks_needed_for_next_move
					@ticks_needed_for_next_move = rand(5)+4
					@current_computer_tick = 0
					#MAKE A MOVE
					made_a_move = false
					if @computer_current_destination[1] < @computer_goal_destination[1]
						@computer_current_destination[1] += 1
						rotate 0 #Rotera om det behövs
						made_a_move = true
					end
					if @computer_current_destination[0] < @computer_goal_destination[0]
						@computer_current_destination[0] += 1
						move_right 0 #Gå åt höger om det behövs
						made_a_move = true
					elsif @computer_current_destination[0] > @computer_goal_destination[0]
						@computer_current_destination[0] -= 1
						move_left 0 #Gå åt vänster om det behövs
						made_a_move = true
					end
					if made_a_move == false && @player_attacks[0].length != 0 && @player_attacks[0][0].y == 544
						#ATTACKS
						type_of_attack = @player_attacks[0][0].attack_type
						if type_of_attack == 0 #Ta bort rad
							if check_height_of_board(@tetris_fields[0]) > 4
								get_type_and_use_attack 0,0
								made_a_move = true
							end
						elsif type_of_attack == 1 #Lägg till rad
							if check_height_of_board(@tetris_fields[1]) > 5
								get_type_and_use_attack 0,1
								made_a_move = true
							end
						end
					end
					if made_a_move == false
						smash 0 #Ta ner blocket om den är i korrekt plats
					end
				end
			end
		end
	end
	def calculate_best_position
		@position_calculated = true
		final_points = [-1000000000000, 0, 0] #poäng, x-värde, rotation
		comp_field = copy_comp_field(@tetris_fields[0]) #Kopia av fältet
		comp_block = @blocks[0][0].block_type #Kopia av datorns block
		comp_blocks = create_comp_blocks(comp_block)
		comp_next_block = @preview_blocks[0][0].block_type #Kopa av datorns nästa block
		comp_next_blocks = create_comp_blocks(comp_next_block)
		possible_rotations = get_possible_rotations comp_block #Get amount of rotations for normal
		possible_next_rotations = get_possible_rotations comp_next_block # and next block
		tracked_x_value_for_points = -5
		move_comp_blocks comp_blocks, -5 #Move all blocks left
		move_comp_blocks comp_next_blocks, -5 # These too
		saved_positions = [] #Saves the position for preview blocks
		comp_next_blocks.each do |block|
			saved_positions << [block.x, block.y]
		end
		current_possible_rotation = 0
		while current_possible_rotation < possible_rotations #Gå igenom alla rotationer

			current_x_value = 0
			while current_x_value < 11 #För alla x
				continue = true
				comp_blocks.each do |block|
					if block.x < 0 || block.x > 9 then continue = false #Kolla så den inte är utanför
					end
				end

				amount_of_blocks_to_move_up = 0
				if continue == true
					comp_field_copy = copy_comp_field(comp_field)
					amount_of_blocks_to_move_up = smash_and_translate_comp_blocks comp_field_copy, comp_blocks
					rows_removed = remove_comp_rows comp_field_copy

					comp_next_blocks.each_with_index do |block,i| #Move the block to the original position
						block.x = saved_positions[i][0]
						block.y = saved_positions[i][1]
					end
					#***************************************************#
					#***************************************************#
					current_possible_next_rotation = 0
					while current_possible_next_rotation < possible_next_rotations
						cur_x_value = 0
						while cur_x_value < 11
							continue = true
							comp_next_blocks.each do |block| #Kolla så ej utanför
								if block.x < 0 || block.x > 9 then continue = false
								end
							end
							amount_of_blocks_fallen = 0
							if continue == true
								comp_new_field_copy = copy_comp_field comp_field_copy
								amount_of_blocks_fallen = smash_and_translate_comp_blocks comp_new_field_copy, comp_next_blocks
								rows_now_removed = remove_comp_rows comp_new_field_copy
									
								#CALCULATE POINTS
								temporary_points = 0
								if rows_removed == 1 then temporary_points -= 83
								else temporary_points += rows_removed * 60
								end #Plus för att ta bort rader
								if rows_now_removed == 1 then temporary_points -= 83
								else temporary_points += rows_now_removed * 60
								end #Plus för att ta bort rader
								current_column_check = 0
								while current_column_check < 10
									current_row_check = 2
									found_the_top = false
									while found_the_top == false
										if current_row_check == 21 || comp_new_field_copy[current_row_check][current_column_check] == 1 then found_the_top = true
										else current_row_check += 1 # hitta toppen på varje kolumn
										end
									end # Minus för höjden
									temporary_points -= (21 - current_row_check)*(21 - current_row_check)
									if current_row_check != 21
										while current_row_check < 22
											if comp_new_field_copy[current_row_check][current_column_check] == 0 then temporary_points -= 10
											else # Minus för blockader
												if current_column_check == 0 then temporary_points += 2.5
												else#Plus för att röra väggarna
													if comp_new_field_copy[current_row_check][current_column_check-1] == 1 then temporary_points += 2
													end #Plus för att röra ett block
												end
												if current_column_check == 9 then temporary_points += 5
												else #Plus för att röra väggarna
													if comp_new_field_copy[current_row_check][current_column_check+1] == 1 then temporary_points += 2
													end #Plus för att röra ett block
												end
											end
											current_row_check += 1
										end
									end
									current_column_check += 1
								end
								if temporary_points > final_points[0]
									final_points[0] = temporary_points
									final_points[1] = tracked_x_value_for_points
									final_points[2] = current_possible_rotation
								end
							end
							cur_x_value += 1
							move_comp_blocks comp_next_blocks, 1, amount_of_blocks_fallen
						end
						current_possible_next_rotation += 1
						if current_possible_next_rotation < possible_next_rotations
							move_comp_blocks comp_next_blocks, -11
							rotate_comp_blocks comp_next_blocks
						end
					end
					#***************************************************#
					#***************************************************#
				end
				tracked_x_value_for_points += 1
				current_x_value += 1
				move_comp_blocks comp_blocks, 1, amount_of_blocks_to_move_up
			end
			current_possible_rotation += 1
			if current_possible_rotation < possible_rotations #Rotera och börja om om det ej är nog
				rotate_comp_blocks comp_blocks
				tracked_x_value_for_points -= 11
				move_comp_blocks comp_blocks, -11
			end
		end
		@computer_goal_destination[0] = final_points[1] #Flytta över x
		@computer_goal_destination[1] = final_points[2] #Flytta över rotation
		@computer_current_destination = [0,0] # Resetta datorns läge
	end
	def get_possible_rotations type
		if type == 1 || type > 5 then return 4
		elsif type == 2 || type > 3 then return 2
		else return 1
		end
	end
	def copy_comp_field field_to_copy_from # Creates a copy of the field because Ruby is retarded.
		new_comp_field = [[0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0]]
		current_row = 2
		while current_row < 22
			current_column = 0
			new_comp_field << []
			while current_column < 10
				cur_block = field_to_copy_from[current_row][current_column]
				if cur_block == 0 then new_comp_field[current_row] << 0
				else new_comp_field[current_row] << 1
				end
				current_column += 1
			end
			current_row += 1
		end
		return new_comp_field
	end
	def print_comp_field field
		puts "***"
		field.each_with_index do |row,i|
			if i > 14 then print "#{row}\n"
			end
		end
		puts "***"
	end

	def create_comp_blocks type
		if type == 1 then return [CompBlock.new(5,2),CompBlock.new(5,1),CompBlock.new(4,2),CompBlock.new(6,2)]
		elsif type == 2 then return [CompBlock.new(4,2),CompBlock.new(3,2),CompBlock.new(5,2),CompBlock.new(6,2)]
		elsif type == 3 then return [CompBlock.new(4,1),CompBlock.new(4,2),CompBlock.new(5,1),CompBlock.new(5,2)]
		elsif type == 4 then return [CompBlock.new(5,1),CompBlock.new(4,1),CompBlock.new(5,2),CompBlock.new(6,2)]
		elsif type == 5 then return [CompBlock.new(5,2),CompBlock.new(4,2),CompBlock.new(5,1),CompBlock.new(6,1)]
		elsif type == 6 then return [CompBlock.new(4,1),CompBlock.new(4,0),CompBlock.new(4,2),CompBlock.new(5,2)]
		else return [CompBlock.new(5,1),CompBlock.new(5,0),CompBlock.new(5,2),CompBlock.new(4,2)]
		end
	end
	def move_comp_blocks blocks, horizontal, vertical = 0
		blocks.each do |block|
			block.x += horizontal
		end
		if vertical != 0
			blocks.each do |block|
				block.y += vertical
			end
		end
	end
	def rotate_comp_blocks all_tha_blocks
		cx = all_tha_blocks[0].x
		cy = all_tha_blocks[0].y

		all_tha_blocks.each do |block| #Rotera alla blocken
			oldx = block.x
			block.x = block.y + cx - cy
			block.y = cx + cy - oldx
		end
	end
	def smash_and_translate_comp_blocks comp_fieldd, blocks
		found_the_ground = false
		rows_fallen = 0
		while found_the_ground == false
			blocks.each do |block|
				if block.y >= 21 then found_the_ground = true
				elsif comp_fieldd[block.y + 1][block.x] == 1 then found_the_ground = true
				end
			end
			if found_the_ground == false
				rows_fallen -= 1
				blocks.each do |block|
					block.y += 1
				end
			end
		end
		blocks.each do |black|
			comp_fieldd[black.y][black.x] = 1
		end
		return rows_fallen
	end
	def remove_comp_rows field
		current_row = 3
		amount_of_rows = 0
		while current_row < 22
			found_a_hole = false
			field[current_row].each do |block| # Leta igenom varje rad efter hål
				if block == 0
					found_a_hole = true
				end
			end
			if found_a_hole == false #Ta bort raden om det är en full rad
				amount_of_rows += 1
				currently_removing_rownumber = current_row - 1
				while currently_removing_rownumber > 1
					copy_of_row = field[currently_removing_rownumber]
					field[currently_removing_rownumber + 1] = copy_of_row
					currently_removing_rownumber -= 1
				end
				field[2] = [0,0,0,0,0,0,0,0,0,0]
			end
			current_row += 1
		end
		return amount_of_rows
	end

	def attack_p1_p1
		get_type_and_use_attack(0,0)
	end
	def attack_p1_p2
		get_type_and_use_attack(0,1)
	end
	def attack_p2_p1
		get_type_and_use_attack(1,0)
	end
	def attack_p2_p2
		get_type_and_use_attack(1,1)
	end
	def get_type_and_use_attack summoner, victim
		if @player_attacks[summoner].length == 0 || @player_attacks[summoner][0].y != 544 then return
		end # Om spelaren inte har några attacker så returnar man
		attack = @player_attacks[summoner][0].attack_type # Ta reda på spelarens attack
		@attack_big_texts[victim].text = @player_attacks[summoner][0].name
		@attack_big_texts[victim].y, @attack_big_texts[victim].alpha_num = 255,255
		@player_attacks[summoner][0].destroy # --> Remove the attack from the players list
		@player_attacks[summoner].shift # ---------^
		@player_attacks[summoner].each do |attack|
			attack.fall_speed = 0 # Reset the fall speed for all attacks
		end
		if @player_attacks[summoner].length == 0 then @attack_texts[summoner].text = ""
		else @attack_texts[summoner].text = @player_attacks[summoner][0].name
		end
		use_attack victim,attack, summoner # Attackera offret med attacken
	end
	def smash_p1
		smash 0
	end
	def smash_p2
		smash 1
	end
	def smash player
		found_the_ground = false
		amount_of_rows_fallen = 0
		while found_the_ground == false #Flytta ner blocken ett steg tills den hittar marken
			@blocks[player].each do |block|
				if block.grid_y+amount_of_rows_fallen == 21 || @tetris_fields[player][block.grid_y+1+amount_of_rows_fallen][block.grid_x] != 0
					found_the_ground = true
				end
			end
			if found_the_ground == false then amount_of_rows_fallen += 1
			end
		end
		@blocks[player].each do |block|
			block.y += 26 * amount_of_rows_fallen
			block.grid_y += 1 * amount_of_rows_fallen
		end
		translate_blocks(player)
	end

	def translate_blocks player
		current_block = 0
		while current_block < 4
			block_thing = @blocks[player][current_block] # Överför blocken till fältet
			@tetris_fields[player][block_thing.grid_y][block_thing.grid_x] = block_thing
			current_block += 1
		end
		@blocks[player] = []

		# Check for filled rows
		current_row = 0
		rows_to_remove = []
		while current_row < 22
			remove_row = true
			@tetris_fields[player][current_row].each do |block_in_row|
				if block_in_row == 0 then remove_row = false
				end
			end
			if remove_row == true then rows_to_remove << current_row
			end
			current_row += 1
		end
		if rows_to_remove.length != 0
			offset = 0
			if player == 1 then offset = 302
			end
			rows_to_remove.each do |rownumber| # Lägg till effekten på alla rader som ska tas bort
				@removal_animations[player] << FillEffect.create(xxx: 119 + offset, yyy: -15 + rownumber*26)
			end
			@rows_waiting_for_removal[player] = rows_to_remove
		else
			create_new_blocks player, true
			create_new_blocks player
			if player == 0 then @position_calculated = false
			end
		end
	end

	def remove_rows_after_translation player
		row_in_field = 2
		if @rows_waiting_for_removal[player].length > 1
			animation_alpha = @removal_animations[player][0].alpha_num
			shake = 0
			if @rows_waiting_for_removal[player].length == 4
				if animation_alpha < 46 then shake = 3
				elsif animation_alpha < 92 then shake = -3
				elsif animation_alpha < 138 then shake = 2 #Ta fram talet för hur mycket den ska skaka med 4 borttagna rader
				elsif animation_alpha < 184 then shake = -2
				elsif animation_alpha < 210 then shake = 1
				else shake = -0.1
				end
			else
				if animation_alpha < 46 then shake = 2
				elsif animation_alpha < 92 then shake = -2
				elsif animation_alpha < 138 then shake = 1 #Ta fram talet för hur mycket den ska skaka efter 2-3 rader
				elsif animation_alpha < 184 then shake = -1
				elsif animation_alpha < 210 then shake = 0.5
				else shake = -0.1
				end
			end
			if animation_alpha > 236
				extra_minus = 0
				if @rows_waiting_for_removal[player].length == 4 then extra_minus = 1
				end
			end
			@removal_animations[player].each do |animation| #Skaka animationen
					animation.rectangle.move!(0,shake)
				end
			while row_in_field < 22
				@tetris_fields[player][row_in_field].each do |block| #Skaka alla blocken
					if block != 0 then block.y += shake
					end
				end
				row_in_field += 1
			end
			@preview_blocks[player].each do |block| # Skaka preview blocken
				block.y += shake
			end
			@tetris_fields_images[player].y += shake # Skaka fältet
			@current_shake_number[player] += shake # Skakar attackerna
		end
		if @removal_animations[player][0].alpha_num > 236 # Om animationen är klar
			@current_shake_number[player] = 0
			@tetris_fields_images[player].y = 298
			@removal_animations[player].each do |animation|
				animation.destroy
			end
			@removal_animations[player] = []
			@rows_waiting_for_removal[player].each do |row|
				@tetris_fields[player][row].each do |block|
					if block.kind_of? Attack
						if @player_attacks[player].length >= 15 then block.destroy
						else
							block.y = 180
							offset = 0
							if player == 1 then offset = 600
							end
							block.x = 100 + offset
							@player_attacks[player] << block # Move attack to attack meter
							if @player_attacks[player].length == 1 then @attack_texts[player].text = @player_attacks[player][0].name
							end
						end
					end
				end
				remove_a_row(player,row) #Ta bort varje rad en för en
			end
			update_blocks(player)
			if @rows_waiting_for_removal[player].length ==4
				add_attack_orb player
			end
			if @rows_waiting_for_removal[player].length > 1
				add_attack_orb player
			end

			@rows_waiting_for_removal[player] = []
			create_new_blocks player, true
			create_new_blocks player
			if player == 0 then @position_calculated = false
			end
		end
	end

	def add_attack_orb player
		type = rand(7)
		possible_rows = []
		current_row = 2
		while current_row < 22
			empty_holes = 0
			@tetris_fields[player][current_row].each do |block|
				if block == 0  || block.is_a?(Attack)
					empty_holes += 1
				end
			end
			if empty_holes < 10
				possible_rows << current_row
			end
			current_row += 1
		end
		row_to_put = possible_rows[rand(possible_rows.length)]
		possible_blocks = []
		current_block = 0
		while current_block < 10
			block = @tetris_fields[player][row_to_put][current_block]
			unless block == 0  || block.is_a?(Attack)
				possible_blocks << current_block
			end
			current_block += 1
		end
		block_to_put = possible_blocks[rand(possible_blocks.length)]
		location = @tetris_fields[player][row_to_put][block_to_put]
		x_value = location.x
		y_value = location.y

		@tetris_fields[player][row_to_put][block_to_put].destroy
		@tetris_fields[player][row_to_put][block_to_put] = Attack.create(x: x_value, y: y_value, gridx: block_to_put, gridy: row_to_put, attack_type: type )
		OrbSparkle.create(x: x_value - 5, y: y_value - 5)
	end

	def create_new_blocks player, preview = false
		offset = 0
		gk, pk, ey = 1 , 0, 0
		if preview == true
			if @current_block_numbers[player] < 20
				type = @first_blocks[@current_block_numbers[player] + 2]
			else
				type = rand(7) + 1
				if @current_block_numbers[player] == 20 then @next_block_types[player] = @preview_blocks[player][0].block_type
				end
			end
			gk = 0 # grid k
			pk = 1 # preview k
			ey = 2 # extra y
			if player == 1 then offset = 677
			end
		else
			@current_block_numbers[player] += 1
			if @current_block_numbers[player] < 21
				type = @first_blocks[@current_block_numbers[player]]
			else
				type = @next_block_types[player]
				@next_block_types[player] = @preview_blocks[player][0].block_type
			end
			if player == 1 then offset = 302
			end
		end
		if type == 1 # x = 21 - 60 - 99    y = 55 - 91 - 133
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (50)*gk + 104*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: true)
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (24)*gk + 78*pk, gridx: 5, gridy: 1 +ey, block_type: type, is_center: false) # T
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (35+offset)*pk, y: (50)*gk + 104*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (288 +offset)*gk + (87+offset)*pk, y: (50)*gk + 104*pk, gridx: 6, gridy: 2 +ey, block_type: type, is_center: false)
		elsif type == 2
			@blocks[player][@blocks[player].length] = Block.create(x: (210 +offset)*gk + (22+offset)*pk, y: (50)*gk + 91*pk, gridx: 3, gridy: 2 +ey, block_type: type, is_center: false)# |
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (48+offset)*pk, y: (50)*gk + 91*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: true) # |
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (74+offset)*pk, y: (50)*gk + 91*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: false)# |
			@blocks[player][@blocks[player].length] = Block.create(x: (288 +offset)*gk + (100+offset)*pk, y: (50)*gk + 91*pk, gridx: 6, gridy: 2 +ey, block_type: type, is_center: false)
		elsif type == 3
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (48+offset)*pk, y: (24)*gk + 78*pk, gridx: 4, gridy: 1 +ey, block_type: type, is_center: false)#   __
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (48+offset)*pk, y: (24)*gk + 104*pk, gridx: 5, gridy: 1 +ey, block_type: type, is_center: false)#  |__|
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (74+offset)*pk, y: (50)*gk + 78*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (74+offset)*pk, y: (50)*gk + 104*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: false)
		elsif type == 4
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (35+offset)*pk, y: (24)*gk + 78*pk, gridx: 4, gridy: 1 +ey, block_type: type, is_center: false)# ___
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (24)*gk + 78*pk, gridx: 5, gridy: 1 +ey, block_type: type, is_center: true)#     |___
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (50)*gk + 104*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (288 +offset)*gk + (87+offset)*pk, y: (50)*gk + 104*pk, gridx: 6, gridy: 2 +ey, block_type: type, is_center: false)
		elsif type == 5
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (35+offset)*pk, y: (50)*gk + 104*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: false)# 	  ___
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (50)*gk + 104*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: true)#  ___|
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (61+offset)*pk, y: (24)*gk + 78*pk, gridx: 5, gridy: 1 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (288 +offset)*gk + (87+offset)*pk, y: (24)*gk + 78*pk, gridx: 6, gridy: 1 +ey, block_type: type, is_center: false)
		elsif type == 6
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (48+offset)*pk, y: (-2)*gk + 65*pk, gridx: 4, gridy: 0 +ey, block_type: type, is_center: false)#  |
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (48+offset)*pk, y: (24)*gk + 91*pk, gridx: 4, gridy: 1 +ey, block_type: type, is_center: true)#   |_
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (48+offset)*pk, y: (50)*gk + 117*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (74+offset)*pk, y: (50)*gk + 117*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: false)
		else
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (48+offset)*pk, y: (-2)*gk + 117*pk, gridx: 5, gridy: 0 +ey, block_type: type, is_center: false)#   |
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (74+offset)*pk, y: (24)*gk + 117*pk, gridx: 5, gridy: 1 +ey, block_type: type, is_center: true)#   _|
			@blocks[player][@blocks[player].length] = Block.create(x: (262 +offset)*gk + (74+offset)*pk, y: (50)*gk + 91*pk, gridx: 5, gridy: 2 +ey, block_type: type, is_center: false)
			@blocks[player][@blocks[player].length] = Block.create(x: (236 +offset)*gk + (74+offset)*pk, y: (50)*gk + 65*pk, gridx: 4, gridy: 2 +ey, block_type: type, is_center: false)
		end
		if preview == true
			@preview_blocks[player].each do |preview_block|
				preview_block.destroy
			end
			@preview_blocks[player] = @blocks[player]
			@blocks[player] = []
		end
		@timers[player] = 0 # REsetta timern
	end

	def move_left_p1
		move_left 0
	end
	def move_left_p2
		move_left 1
	end
	def move_left player
		@blocks[player].each do |block| #Kolla så att det inte finns nåt som blockerar åt vänster
			if block.grid_x == 0 || @tetris_fields[player][block.grid_y][block.grid_x - 1] != 0
				return #Gå ut ur funktionen om den träffar nåt
			end
		end
		@blocks[player].each do |block| #Flytta alla block åt vänster
			block.x -= 26
			block.grid_x -= 1
		end
	end
	def move_right_p1
		move_right 0
	end
	def move_right_p2
		move_right 1
	end
	def move_right player
		@blocks[player].each do |block| #Kolla så att det inte finns nåt som blockerar åt höger
			if block.grid_x == 9 || @tetris_fields[player][block.grid_y][block.grid_x + 1] != 0
				return #Gå ut ur funktionen om den träffar nåt
			end
		end
		@blocks[player].each do |block|
			block.x += 26
			block.grid_x += 1
		end
	end
	def move_down_p1
		move_down 0
	end
	def move_down_p2
		move_down 1
	end
	def move_down player
		@down_timers[player] += 1
		if @down_timers[player] > 6 then @down_timers[player] = 1
		end
		if @down_timers[player] == 1
			@blocks[player].each do |block| #Kolla så att det inte finns nåt som blockerar under
				if block.grid_y == 21 then return
				elsif @tetris_fields[player][block.grid_y + 1][block.grid_x] != 0 then return
				end #Gå ut ur funktionen om den träffar nåt
			end
			@timers[player] = 0
			@blocks[player].each do |block|
				block.y += 26
				block.grid_y += 1
			end
		end
	end

	def rotate_p1
		rotate 0
	end
	def rotate_p2
		rotate 1
	end
	def rotate player
		cx,cy,cgridx,cgridy = 0,0,0,0
		@blocks[player].each do |block| #Hitta centerblocket
			if block.center == true
				cx = block.x
				cy = block.y
				cgridx = block.grid_x
				cgridy = block.grid_y
			end
		end
		if cx == 0 then return
		end
		@blocks[player].each do |block| #Checka så att blocken inte kommer röra nåt efter rotationen
			oldx = block.grid_x
			tempx = block.grid_y + cgridx - cgridy
			tempy = cgridx + cgridy - oldx
			if tempy > 21 || tempy < 0 then return
			end
			if tempx < 0 || tempx > 9 || @tetris_fields[player][tempy][tempx] != 0 then return
			end
		end
		@blocks[player].each do |block| #Rotera alla blocken
			oldx = block.x
			block.x = block.y + cx - cy
			block.y = cx + cy - oldx
			oldx = block.grid_x
			block.grid_x = block.grid_y + cgridx - cgridy
			block.grid_y = cgridx + cgridy - oldx
		end
	end

	def check_height_of_board field
		highest_height = 0
		current_column = 0
		while current_column < 10
			current_row = 2
			while current_row < 22
				if field[current_row][current_column] != 0
					if 22 - current_row > highest_height then highest_height = 22 - current_row
					end
					break
				end
				current_row += 1
			end
			current_column += 1
		end
		return highest_height
	end

	def new_game(num_players) # Starta om spelet med nya fräscha spelplaner
		@amount_of_players = num_players
		current_field = 0

		#Ta bort allt från den förra spelomgången
		@attack_texts = []
		@tetris_fields, @player_attacks, @tetris_fields_images = [], [], []
		@current_block_numbers, @next_block_types, @current_shake_number = [],[],[]
		@timers, @down_timers = [],[]
		@blocks, @next_blocks, @preview_blocks, @first_blocks, @field_blocks = [],[],[],[],[]
		@rows_waiting_for_removal, @removal_animations = [],[]
		50.times do
			@first_blocks << rand(7)+1 # Skapa de 50 gemensamma första blocken
		end
		while current_field < @amount_of_players # Skapar nya spelplaner
			@tetris_fields[current_field] = []
			22.times do
				@tetris_fields[current_field] << [0,0,0,0,0,0,0,0,0,0] #Lägger till alla rader på spelplanen
			end

			@timers[current_field] = 0
			@down_timers[current_field] = 0
			@current_block_numbers[current_field] = -1
			@next_block_types[current_field] = []
			@current_shake_number[current_field] = 0
			@blocks[current_field] = []
			@preview_blocks[current_field] = []
			@field_blocks[current_field] = []
			@rows_waiting_for_removal[current_field] = []
			@removal_animations[current_field] = []
			@player_attacks[current_field] = []
			text_offset = 0
			if current_field == 1 then text_offset = 597
			end
			@attack_texts[current_field] = AttackSmallText.create(x: 100 + text_offset)
			@attack_big_texts[current_field] = AttackText.create(x: 245 + text_offset/1.96)
			@tetris_fields_images[current_field] = TetrisField.create(player: current_field)
			create_new_blocks current_field, true
			create_new_blocks current_field
			current_field += 1
		end
	end

	def remove_a_row player, row_number, attack = false
		@tetris_fields[player][row_number].each do |column|
			if column.kind_of? Block then column.destroy
			end
			if attack == true
				if column.kind_of? Attack then column.destroy
				end
			end
		end
		@tetris_fields[player][row_number] = [0,0,0,0,0,0,0,0,0,0] #Ta bort raden
		current_row = row_number - 1
		while current_row >= 0
			copy_of_row = @tetris_fields[player][current_row]
			@tetris_fields[player][current_row + 1] = copy_of_row
			@tetris_fields[player][current_row + 1].each do |block_thing|
				if block_thing != 0 then block_thing.grid_y += 1
				end
			end
			current_row -= 1
		end
		@tetris_fields[player][0] = [0,0,0,0,0,0,0,0,0,0]
	end
#-----------------------------------------------------------------------------------------------------------------
	def attack_add_row player
		current_row = 2
		while current_row < 22
			copy_of_row = @tetris_fields[player][current_row]
			@tetris_fields[player][current_row - 1] = copy_of_row
			@tetris_fields[player][current_row - 1].each do |block_thing|
				if block_thing != 0 then block_thing.grid_y -= 1
				end
			end
			current_row += 1
		end
		hole_number = rand(10)
		new_row = [1,1,1,1,1,1,1,1,1,1]
		new_row[hole_number]= 0
		xoffset = 0
		if player == 1 then xoffset = 302
		end
		current_number = 0
		while current_number < 10
			if new_row[current_number] == 1
				type = rand(7) + 1
				new_row[current_number] = Block.create(x: 132 + 26*current_number +xoffset, y:  544, gridx: current_number, gridy: 21, block_type: type, is_center: false)
			end
			current_number += 1
		end
		@tetris_fields[player][21] = new_row
	end

	def attack_earthquake player
		@tetris_fields[player].each do |row|
			row.shuffle!
			row.each_with_index do |block,place|
				if block != 0
					offset = place - block.grid_x
					block.grid_x += offset
				end
			end
		end
	end

	def attack_erase_board player, from_copy_board = false
		@tetris_fields[player].each do |row|
			row.each do |block|
				if block != 0 then block.destroy
				end
			end
		end
		@tetris_fields[player] = []
		if from_copy_board == false
			22.times do
				@tetris_fields[player] << [0,0,0,0,0,0,0,0,0,0] #Lägger till alla rader på spelplanen
			end
		end
	end
	def attack_ladder player
		current_row = rand(2)+1
		while current_row < 21
			@tetris_fields[player][current_row].each do |block|
				if block != 0 then block.destroy
				end
			end
			@tetris_fields[player][current_row] = [0,0,0,0,0,0,0,0,0,0]
			current_row += 2
		end
	end

	def attack_copy_board player, summoner
		if player == summoner then return
		end
		attack_erase_board summoner, true
		player_field = @tetris_fields[summoner]
		@tetris_fields[player].each_with_index do |row, current_row|
			player_field << []
			row.each_with_index do |block, current_block|
				if block == 0 then player_field[current_row] << 0
				elsif block.kind_of? Block
					player_field[current_row] << Block.create( gridx: block.grid_x, gridy: block.grid_y, block_type: block.block_type, is_center: false)
				else
					player_field[current_row] << Attack.create( gridx: block.grid_x, gridy: block.grid_y, attack_type: block.attack_type)
				end
			end
		end
		update_blocks summoner
	end

	def attack_acid_trip player
		type = rand(7)+1
		@tetris_fields[player].each do |row|
			row.each do |block|
				if block.kind_of? Block
					block.angle += rand(5)+3
					block.block_type = type
					block.factor += rand(0.05)/ 10.0
					if block.factor_x > 1.5 then block.factor = 0.3
					end
					if type == 1 then block.image = Gosu::Image[$tileset + "/block_green.png"]
					elsif type == 2 then block.image = Gosu::Image[$tileset + "/block_red.png"]
					elsif type == 3 then block.image = Gosu::Image[$tileset + "/block_darkblue.png"]
					elsif type == 4 then block.image = Gosu::Image[$tileset + "/block_orange.png"]
					elsif type == 5 then block.image = Gosu::Image[$tileset + "/block_lightblue.png"]
					elsif type == 6 then block.image = Gosu::Image[$tileset + "/block_purple.png"]
					else block.image = Gosu::Image[$tileset + "/block_yellow.png"]
					end
				end
			end
		end
	end
	def attack_end_acid_trip player
		@tetris_fields[player].each do |row|
			row.each do |block|
				if block.kind_of? Block
					block.angle = 0
					block.factor = 1
				end
			end
		end
	end

	def use_attack player, attack_number, summoner
		if attack_number == 0 then remove_a_row(player,21,true)
		elsif attack_number == 1 then attack_add_row(player)
		elsif attack_number == 2 then attack_earthquake player
		elsif attack_number == 3 then attack_copy_board player, summoner
		elsif attack_number == 4 then attack_erase_board player	
		elsif attack_number == 5 then attack_ladder player 
		elsif attack_number == 6 then AcidHandler.create(victim: player)
		end
		update_blocks(player)
		xoffset = 0
		if player == 1 then xoffset = 306
		end
		initial_spawn = rand(4)+5
		after_spawn = rand(7)+20
		initial_spawn.times do
			AttackSparkle.create(type: rand(3), time: 0, screen_time: rand(60)+30, max_size: rand(0.25)+0.75, x: rand(230)+135+xoffset, y: rand(495)+50)
		end
		after_spawn.times do
			AttackSparkle.create(type: rand(3), time: rand(70), screen_time: rand(60)+30, max_size: rand(0.25)+0.75, x: rand(230)+135+xoffset, y: rand(495)+50)
		end
	end
#----------------------------------------------------------------------------------------------------------------
	def update_blocks player
		row = 0
		xoffset = 0
		if player == 1 then xoffset = 302 #Gör så att blocken hamnar på högra planen om det är player 2
		end
		while row < @tetris_fields[player].length # Gå igenom varenda block och uppdatera dens x och y värden
			@tetris_fields[player][row].each do |block_in_row|
				if block_in_row != 0
					block_in_row.x = block_in_row.grid_x * 26 + 132 + xoffset
					block_in_row.y = block_in_row.grid_y * 26 - 2
				end
			end
			row += 1
		end
	end
end

class Block < Chingu::GameObject
	attr_accessor :grid_x, :grid_y, :block_type, :acid_direction
	attr_reader :center
	attr_writer :image
	def setup
		@block_type = @options[:block_type] # Bestämmer färgen på blocket
		if @block_type == 1 then @image = Gosu::Image[$tileset + "/block_green.png"]
		elsif @block_type == 2 then @image = Gosu::Image[$tileset + "/block_red.png"]
		elsif @block_type == 3 then @image = Gosu::Image[$tileset + "/block_darkblue.png"]
		elsif @block_type == 4 then @image = Gosu::Image[$tileset + "/block_orange.png"]
		elsif @block_type == 5 then @image = Gosu::Image[$tileset + "/block_lightblue.png"]
		elsif @block_type == 6 then @image = Gosu::Image[$tileset + "/block_purple.png"]
		else @image = Gosu::Image[$tileset + "/block_yellow.png"]
		end
		@grid_x = @options[:gridx]
		@grid_y = @options[:gridy]
		@center = @options[:is_center]
	end
	def draw
		if @grid_y < 2 then return # Gör så att den är osynlig om den är högst upp!
		end
		super
	end
end

class CompBlock
	attr_accessor :x, :y
	def initialize x,y
		@x = x
		@y = y
	end
end

class Attack < Chingu::GameObject
	attr_accessor :grid_x, :grid_y, :fall_speed
	attr_reader :attack_type, :name
	def setup
		@attack_type = @options[:attack_type]
		if @attack_type == 0
			@image = Gosu::Image["orbs/attack_0.png"]
			@name = "Remove row"
		elsif @attack_type == 1
			@image = Gosu::Image["orbs/attack_1.png"]
			@name = "Add row"
		elsif @attack_type == 2
			@image = Gosu::Image["orbs/attackpurple.png"]
			@name = "Earthquake"
		elsif @attack_type == 3
			@image = Gosu::Image["orbs/ballpink.png"]
			@name = "Copy board"	
		elsif @attack_type == 4
			@image = Gosu::Image["orbs/ballgrey.png"]
			@name = "Erase board"
		elsif @attack_type == 5
			@image = Gosu::Image["orbs/ballbrown.png"]
			@name = "Ladder attack"
		elsif @attack_type == 6 
			@image = Gosu::Image["orbs/ballacid.png"]
			@name = "Acid trip"
		end
		@grid_x = @options[:gridx]
		@grid_y = @options[:gridy]
		@fall_speed = 0
	end
end
class OrbSparkle < Chingu::GameObject
	def setup
		@animation = Chingu::Animation.new(:file => "effects/sparkle_26x26.png", :loop => false, :index => 0)
		@animation.frame_names = {:sparkle => 0..10}
		@frame_name = :sparkle
	end
	def update
		if @animation[@frame_name].index == 10 then self.destroy
		end
		@image = @animation[@frame_name].next!
	end
end
class AttackSparkle < Chingu::GameObject
	def setup
		image_type = @options[:type]
		if image_type == 0 then @image = Gosu::Image["effects/sparkle0.png"]
		elsif image_type == 1 then @image = Gosu::Image["effects/sparkle1.png"]
		elsif image_type == 2 then @image = Gosu::Image["effects/sparkle2.png"]
		end
		@timer = @options[:time]
		@screen_time = @options[:screen_time]
		@max_size = @options[:max_size]
		self.factor = 0
	end
	def update
		@timer -= 1
		if @timer < 0
			@screen_time -= 1
			if @screen_time > 0
				if self.factor_x < @max_size then self.factor += 0.06
				end
			else
				if self.factor_x > 0.1 then self.factor -= 0.06
				else self.destroy
				end
			end
		end
	end
end

class Background < Chingu::GameObject
	def setup 
		@image = Gosu::Image["bg/testbakgrund.png"]
		@x, @y = 400, 300
	end
end
class TetrisField < Chingu::GameObject
	def setup
		if @options[:player] == 0
			@image = Gosu::Image["bg/blue_field.png"]
			@x = 193
		else 
			@image = Gosu::Image["bg/red_field.png"]
			@x = 607
		end
		@y = 298
	end
end

class FillEffect < Chingu::GameObject # Effekten som uppstår när man fyller en rad
	attr_reader :alpha_num
	attr_accessor :rectangle
	def setup
		@x_location = @options[:xxx]
		@y_location = @options[:yyy]
		@rectangle = Chingu::Rect.new(@x_location,@y_location,260,26) #Skapar rektangeln
		@alpha_num = 0 # Håller koll på alphan
		@color_num = 255 # Färgen
	end

	def draw
		@alpha_num += 7 # Ökar alphan varje frame så att det ser ut som den tonas in
		@color_num -= 7
		colour = Gosu::Color.new(@alpha_num, @color_num, @color_num, @color_num) # Gör en ny färg med alpha-värdet
		$window.fill_rect(@rectangle, colour, 103) # Ritar rektangeln
	end
end

class AttackText < Chingu::GameObject
	attr_writer :text, :alpha_num, :y
	def setup
		@font = Gosu::Font.new($window, "bauhaus", 60)
		@text = ""
		@y = 255
		@alpha_num = 0
	end
	def draw
		super
		unless @alpha_num < 1 # Animera sketen
			@alpha_num -= 4
			@y += 1
			colour = Gosu::Color.new(@alpha_num, 200, 200, 200)
			@font.draw_rel(@text, @x, @y, 104, 0.5, 0.5,0.6,1,colour)
		end
	end
end

class AttackSmallText < Chingu::GameObject
	attr_writer :text
	def setup
		@font = Gosu::Font.new($window, "verdana", 20)
		@text = ""
	end
	def draw
		super
		@font.draw_rel(@text, @x, 582, 102, 0.5,1,1,1,0xff000000)
	end
end

class AcidHandler < Chingu::BasicGameObject
	def setup
		@time_left = 1500
		@victim = @options[:victim]
	end
	def update
		@time_left -= 1
		if @time_left > 0
			parent.attack_acid_trip @victim
		else
			parent.attack_end_acid_trip @victim
			self.destroy
		end
	end
end
game_window = Game.new.show

# Add row !!!!
# Remove row !!!!
# Earthquake !!!!
# Delete attacks
# Shotgun
# Equalization
# Erase board !!!!
# Copy board !!!!
# Minefield
# Sploosh
# Ladder !!!
# Haste
