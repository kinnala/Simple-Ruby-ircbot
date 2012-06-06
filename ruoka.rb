class Ruoka < IRC_Module

    def hooks
        ["ruoka", "vote"]
    end

    def synon(str)
        synonyms = {
            'tf' => 'taffa',
            'täffä' => 'taffa',
            'sodexo' => 'teekkariravintolat',
            'dipoli' => 'teekkariravintolat',
            't-talo' => 'teekkariravintolat',
            'quarkki' => 'kvarkki',
            'alvari' => 'alvari',
            'taffa' => 'taffa',
            'teekkariravintolat' => 'teekkariravintolat',
            'kvarkki' => 'kvarkki',
            'keltsu' => 'cantina',
            'cantina' => 'cantina',
            'tuas' => 'tuas'
        }
        synonyms[str]
    end

    def vote
        if @params[0] == nil then
            answer "Usage: !vote new/status/<restaurant>"
            return
        end

        if @params[0] == "status" then

            if @vote_status == nil then
                answer "You have to start a new vote first. Use: !vote new"
                return
            end

            msg = "Votes: "

            @vote_status.each { |key, value|
                if key != nil then
                    msg = "#{msg}#{key} #{value}, "
                end
            }

            answer msg.chop.chop

            msg = "Already voted: "
            @already_voted.each { |name|
                msg = "#{msg}#{name}, "
            }
            answer msg.chop.chop
        
            return    
        end

        if @params[0] == "new" then
            @vote_status = { }
            @already_voted = [ ]

            answer "Vote now!"
            return
        end

        if @vote_status == nil then
            answer "You have to start a new vote first. Use: !vote new"
            return
        end

        if @already_voted.include? @nick then
            answer "You have voted already!"
            return
        end

        if self.synon(@params[0]) == nil then
            answer "No such restaurant found!"
            return
        end

        if @vote_status[self.synon(@params[0])] == nil then
            @vote_status[self.synon(@params[0])] = 1
        else
            @vote_status[self.synon(@params[0])] += 1
        end
        
        answer "#{self.synon(@params[0])}, #{@vote_status[self.synon(@params[0])]} votes."

        @already_voted = @already_voted << @nick

    end

    def ruoka
        if @params[1] == nil then
            answer "Usage: !ruoka <day> <restaurant>"
            return
        end

        weekdays = ["ma","ti","ke","to","pe","la","su"]

        place = self.synon(@params[1])
        day = @params[0]

        Net::HTTP.start("www.lounasaika.net") { |http|
            str = http.get("/rss/#{place}/").body
            str = str.gsub("&lt;br/&gt;",", ")
            str = str.gsub("&amp;#039;","")
            str = str.gsub("&amp;ouml;","ö")
            str = str.gsub("&amp;auml;","ä")
            str = str.gsub("&amp;Agrave; ","A")
            str = str.gsub("\n","")
            str = str.gsub("&amp;nbsp;","")
            for i in (1..20)
                str = str.gsub("  "," ")
            end
            str = str.gsub(" ,",",")

            doc = REXML::Document.new str
            i = 0

            doc.elements.each("rss/channel/item/description") { |element|
                if day == weekdays[i] and element.text != nil then
                    answer element.text.lstrip
                end
                i = i + 1
            }
        }
    end
end
