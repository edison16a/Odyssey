//
//  ExploreSearchTerms.swift
//  Odyssey
//
//  The things you can search for in Explore, around a thousand of them:
//  cuisines, dishes, drinks, shops, activities, outdoor spots and moods
//  like "quiet study spot" or "late night tacos". Each one knows the words
//  to look for in a place's name and OpenStreetMap tags, and the Explore
//  category to fall back on when nothing matches the words exactly.
//
//  The list is built from short word lists below, so adding a dish is one
//  word, not a new entry by hand.
//

import Foundation

nonisolated struct ExploreQuery: Hashable, Sendable {
    var text: String
    var cats: [String]
    var words: [String]
}

nonisolated enum ExploreSearchTerms {
    static let all: [ExploreQuery] = build()

    /// Up to eight suggestions: whole prefix first, then a word starting with it, then anywhere.
    static func suggestions(_ typed: String, limit: Int = 8) -> [ExploreQuery] {
        let q = typed.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var scored: [(Int, ExploreQuery)] = []
        for term in all {
            let t = term.text
            if t.hasPrefix(q) { scored.append((0, term)) }
            else if t.contains(" " + q) { scored.append((1, term)) }
            else if t.contains(q) { scored.append((2, term)) }
        }
        return scored.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.text.count < $1.1.text.count }.prefix(limit).map(\.1)
    }

    /// A known term for the text, or a free search built from its words.
    static func query(for typed: String) -> ExploreQuery {
        let q = typed.lowercased().trimmingCharacters(in: .whitespaces)
        if let hit = all.first(where: { $0.text == q }) { return hit }
        let words = q.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let cats = ([q] + words).lazy.compactMap { suggestions($0, limit: 1).first?.cats }.first ?? []
        return ExploreQuery(text: q, cats: cats, words: words.isEmpty ? [q] : words)
    }

    // MARK: Word lists

    private static let cuisines = ["italian", "mexican", "thai", "chinese", "japanese", "korean", "vietnamese", "indian",
        "greek", "french", "spanish", "turkish", "lebanese", "ethiopian", "moroccan", "peruvian", "brazilian", "cuban",
        "filipino", "malaysian", "indonesian", "burmese", "nepalese", "pakistani", "afghan", "persian", "israeli",
        "mediterranean", "middle eastern", "american", "southern", "cajun", "hawaiian", "caribbean", "jamaican",
        "salvadoran", "colombian", "argentinian", "german", "polish", "russian", "ukrainian", "georgian", "british",
        "irish", "portuguese", "taiwanese", "cantonese", "szechuan", "shanghainese", "hunan", "mongolian", "tibetan",
        "sri lankan", "bangladeshi", "west african", "nigerian", "senegalese", "egyptian", "yemeni", "uzbek",
        "scandinavian", "basque", "venezuelan", "oaxacan", "tex mex", "fusion", "vegan", "vegetarian", "halal",
        "kosher", "gluten free", "seafood", "soul food"]

    private static let dishes = ["tacos", "burritos", "pizza", "ramen", "pho", "sushi", "burgers", "dumplings", "dim sum",
        "noodles", "pasta", "curry", "falafel", "shawarma", "kebab", "gyros", "bbq", "fried chicken", "wings", "hot pot",
        "korean bbq", "bibimbap", "banh mi", "poke", "bagels", "sandwiches", "salads", "soup", "steak", "oysters",
        "lobster rolls", "fish and chips", "brunch", "breakfast", "pancakes", "waffles", "crepes", "omelettes",
        "croissants", "donuts", "cupcakes", "cookies", "cake", "pie", "macarons", "gelato", "ice cream", "frozen yogurt",
        "churros", "mochi", "bao", "xiao long bao", "udon", "soba", "tempura", "katsu", "teriyaki", "tamales", "pupusas",
        "empanadas", "arepas", "ceviche", "paella", "tapas", "mezze", "hummus", "dosa", "biryani", "tikka masala",
        "naan", "samosas", "pad thai", "green curry", "laksa", "spring rolls", "fried rice", "chow mein", "peking duck",
        "mapo tofu", "kimchi", "tteokbokki", "onigiri", "hand rolls", "omakase", "acai bowls", "smoothies", "juice",
        "grain bowls", "wraps", "hot dogs", "cheesesteak", "mac and cheese", "pretzels", "baguettes", "sourdough",
        "cinnamon rolls", "scones", "pastries", "chocolate", "candy", "fondue", "raclette", "pierogi", "borscht",
        "khachapuri", "jollof", "injera", "tagine", "couscous", "lamb", "ribs", "brisket", "pulled pork", "crab",
        "clam chowder", "poutine", "nachos", "quesadillas", "elote", "birria", "mole", "chilaquiles", "huevos rancheros"]

    private static let drinks = ["coffee", "espresso", "latte", "cappuccino", "cortado", "flat white", "cold brew",
        "pour over", "matcha", "chai", "tea", "bubble tea", "boba", "hot chocolate", "kombucha", "craft beer", "beer",
        "wine", "natural wine", "cocktails", "mocktails", "whiskey", "sake", "cider", "mezcal", "tequila", "gin",
        "espresso martini", "happy hour", "milkshakes", "lemonade", "horchata", "thai iced tea", "vietnamese coffee",
        "turkish coffee", "affogato", "oat milk latte", "iced coffee", "decaf", "herbal tea"]

    private static let shops = ["bookstore", "used books", "comic shop", "record store", "vinyl", "thrift store",
        "vintage clothing", "consignment", "sneakers", "streetwear", "boutique", "shoe store", "jewelry", "watches",
        "eyewear", "hat shop", "plant shop", "florist", "garden center", "hardware store", "home goods", "furniture",
        "antiques", "art supplies", "stationery", "paper goods", "gift shop", "toy store", "game store", "board games",
        "video games", "electronics", "camera shop", "music instruments", "guitar shop", "bike shop", "outdoor gear",
        "running shoes", "sporting goods", "skate shop", "surf shop", "bakery", "butcher", "cheese shop", "wine shop",
        "liquor store", "grocery", "farmers market", "asian market", "deli", "spice shop", "tea shop", "chocolate shop",
        "candy store", "pet store", "barber", "hair salon", "nail salon", "spa", "tattoo", "perfume", "cosmetics",
        "skincare", "pharmacy", "department store", "mall", "outlet", "kitchen supplies", "craft store", "fabric store",
        "yarn shop", "frame shop", "print shop", "pop up shop", "flea market", "night market", "souvenirs", "map shop"]

    private static let activities = ["bouldering", "climbing gym", "yoga", "pilates", "spin class", "boxing", "gym",
        "crossfit", "swimming", "pool", "tennis", "pickleball", "basketball", "soccer", "running track", "skatepark",
        "ice skating", "roller skating", "bowling", "billiards", "darts", "karaoke", "arcade", "escape room",
        "mini golf", "golf", "driving range", "batting cages", "trampoline park", "laser tag", "go karts", "axe throwing",
        "pottery class", "painting class", "cooking class", "dance class", "salsa dancing", "comedy club", "live music",
        "jazz club", "open mic", "concert", "theater", "musical", "opera", "ballet", "cinema", "indie cinema",
        "drive in movie", "museum", "art gallery", "science museum", "history museum", "planetarium", "aquarium", "zoo",
        "botanical garden", "amusement park", "trivia night", "board game cafe", "cat cafe", "library", "reading room",
        "lecture", "book club", "walking tour", "food tour", "boat tour", "kayaking", "paddleboarding", "sailing",
        "fishing", "birdwatching", "stargazing", "picnic", "photo walk", "sunset", "sunrise"]

    private static let outdoors = ["park", "dog park", "playground", "garden", "rose garden", "beach", "lake", "pond",
        "river walk", "waterfront", "pier", "marina", "harbor", "hiking trail", "nature trail", "viewpoint", "lookout",
        "hilltop", "waterfall", "forest", "redwoods", "meadow", "plaza", "square", "courtyard", "fountain", "bridge",
        "lighthouse", "campus", "cemetery", "nature reserve", "wetlands", "bike path", "community garden", "rooftop garden",
        "public art", "murals", "street art", "sculpture park", "monument", "landmark", "historic site", "old town",
        "chinatown", "japantown", "little italy", "downtown", "farmers market square", "boardwalk", "dunes", "cliffs",
        "tide pools", "hot springs", "lawn", "amphitheater", "skyline view", "observation deck", "tower"]

    private static let vibes: [(String, String, String)] = [
        ("quiet study spot", "study", "library,cafe,coworking"), ("cozy cafe", "coffee", "cafe"),
        ("cafe with wifi", "study", "cafe"), ("laptop friendly cafe", "study", "cafe"),
        ("late night tacos", "food", "taco,mexican"), ("late night food", "food", "fast food,restaurant"),
        ("open late", "food", "bar,restaurant"), ("rooftop", "nightlife", "rooftop,bar"), ("rooftop bar", "nightlife", "bar"),
        ("date night", "food", "restaurant,wine"), ("first date", "coffee", "cafe,wine"), ("group dinner", "food", "restaurant"),
        ("hidden gem", "food", "restaurant,cafe"), ("local favorite", "food", "restaurant"), ("hole in the wall", "food", "restaurant"),
        ("outdoor seating", "food", "restaurant,cafe"), ("patio", "food", "restaurant,bar"), ("dog friendly", "park", "park,cafe"),
        ("kid friendly", "park", "playground,park"), ("family day out", "entertainment", "museum,zoo,park"),
        ("rainy day", "entertainment", "museum,cinema,library"), ("sunny afternoon", "park", "park,beach"),
        ("cheap eats", "food", "fast food,restaurant"), ("treat yourself", "dessert", "bakery,ice cream"),
        ("sweet tooth", "dessert", "bakery,ice cream,confectionery"), ("healthy lunch", "food", "salad,vegan"),
        ("quick lunch", "food", "fast food,sandwich"), ("lunch spot", "food", "restaurant,sandwich"),
        ("solo dinner", "food", "ramen,restaurant"), ("live jazz", "nightlife", "jazz,bar"), ("dive bar", "nightlife", "bar,pub"),
        ("sports bar", "nightlife", "bar,pub"), ("wine bar", "nightlife", "wine,bar"), ("cocktail bar", "nightlife", "cocktail,bar"),
        ("speakeasy", "nightlife", "cocktail,bar"), ("brewery", "nightlife", "brewery,pub"), ("beer garden", "nightlife", "biergarten,pub"),
        ("dance floor", "nightlife", "nightclub"), ("night out", "nightlife", "bar,nightclub"), ("chill evening", "nightlife", "bar,pub"),
        ("work from a cafe", "study", "cafe"), ("coworking", "study", "coworking"), ("read a book", "library", "library,cafe"),
        ("people watching", "coffee", "cafe,plaza"), ("good view", "park", "viewpoint,park"), ("scenic walk", "park", "park,garden"),
        ("morning run", "park", "park,track"), ("workout", "fitness", "fitness,gym"), ("stretch and relax", "fitness", "yoga,spa"),
        ("self care", "shopping", "spa,beauty"), ("gift shopping", "shopping", "gift,books"), ("window shopping", "shopping", "clothes,boutique"),
        ("vintage hunting", "shopping", "second hand,vintage"), ("record digging", "shopping", "music,record"),
        ("art afternoon", "entertainment", "gallery,museum"), ("culture day", "entertainment", "museum,theatre,gallery"),
        ("free things to do", "park", "park,library,museum"), ("something new", "entertainment", "attraction"),
        ("tourist spots", "entertainment", "attraction,museum"), ("instagram spot", "entertainment", "attraction,viewpoint"),
        ("fill up gas", "gas", "fuel"), ("charge my car", "gas", "charging"), ("independent coffee", "coffee", "cafe"),
        ("third wave coffee", "coffee", "cafe,roastery"), ("bakery morning", "dessert", "bakery"), ("pastry run", "dessert", "bakery,pastry"),
    ]

    // MARK: Building the list

    private static func build() -> [ExploreQuery] {
        var out: [ExploreQuery] = []
        var seen = Set<String>()
        func add(_ text: String, _ cats: [String], _ words: [String]) {
            guard seen.insert(text).inserted else { return }
            out.append(ExploreQuery(text: text, cats: cats, words: words))
        }
        for v in vibes { add(v.0, [v.1], v.2.split(separator: ",").map(String.init)) }
        for c in cuisines {
            for form in [c, c + " food", c + " restaurant", "cheap " + c, "best " + c, "late night " + c] {
                add(form, ["food"], [c, "restaurant"])
            }
        }
        for d in dishes {
            let cat = dessertWords.contains(d) ? "dessert" : "food"
            for form in [d, "best " + d] { add(form, [cat], [d]) }
        }
        for d in drinks {
            let cat = barWords.contains(d) ? "nightlife" : "coffee"
            for form in [d, "best " + d] { add(form, [cat], [d]) }
        }
        for s in shops { add(s, [shopCategory(s)], [s]) }
        for a in activities { add(a, [activityCategory(a)], [a]) }
        for o in outdoors { add(o, [o.contains("view") || o.contains("deck") || o == "tower" ? "entertainment" : "park"], [o]) }
        return out
    }

    private static let dessertWords: Set<String> = ["donuts", "cupcakes", "cookies", "cake", "pie", "macarons", "gelato",
        "ice cream", "frozen yogurt", "churros", "mochi", "croissants", "cinnamon rolls", "scones", "pastries",
        "chocolate", "candy", "pancakes", "waffles", "crepes"]
    private static let barWords: Set<String> = ["craft beer", "beer", "wine", "natural wine", "cocktails", "mocktails",
        "whiskey", "sake", "cider", "mezcal", "tequila", "gin", "espresso martini", "happy hour"]

    private static func shopCategory(_ s: String) -> String {
        if ["bakery", "chocolate shop", "candy store"].contains(s) { return "dessert" }
        if ["butcher", "cheese shop", "deli", "grocery", "farmers market", "asian market", "spice shop"].contains(s) { return "food" }
        return "shopping"
    }

    private static func activityCategory(_ a: String) -> String {
        let fit = ["bouldering", "climbing gym", "yoga", "pilates", "spin class", "boxing", "gym", "crossfit", "swimming",
                   "pool", "tennis", "pickleball", "basketball", "soccer", "running track", "skatepark"]
        if fit.contains(a) { return "fitness" }
        if ["karaoke", "comedy club", "live music", "jazz club", "open mic", "trivia night"].contains(a) { return "nightlife" }
        if ["library", "reading room", "lecture", "book club"].contains(a) { return "library" }
        if ["kayaking", "paddleboarding", "sailing", "fishing", "birdwatching", "stargazing", "picnic", "sunset", "sunrise",
            "photo walk"].contains(a) { return "park" }
        if ["board game cafe", "cat cafe"].contains(a) { return "coffee" }
        return "entertainment"
    }
}
