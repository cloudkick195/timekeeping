package commons

type Pagination struct {
	Limit  int    `json:"limit" form:"limit"`
	Page   int    `json:"page" form:"page"`
	Offset int    `json:"offset" form:"offset"`
	Sort   string `json:"sort" form:"sort"`
	Query  string `json:"query" form:"query"`
	Total  int64  `json:"total" form:"total"`
}

func (a *Pagination) HandleRequest() {
	if a.Limit == 0 {
		a.Limit = 10
	}

	if a.Page == 0 {
		a.Page = 1
	}

	if a.Sort == "" {
		a.Sort = "created_at desc"
	}
	a.Offset = (a.Page - 1) * a.Limit
}
