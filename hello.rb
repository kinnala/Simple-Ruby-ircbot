class Hello < IRC_Module

    def hooks
        ["hello"]
    end

    def hello
        answer "Moro!"
        answer @params[0]
    end

end
