package javaUtilEx;

public class juHashMapCreateEquals {
	public static void main(String[] args) {
		Random.args = args;

		HashMap<Content,Content> m1 = createMap(Random.random());
		HashMap<Content,Content> m2 = createMap(Random.random());
		m1.equals(m2);
	}

	public static HashMap<Content, Content> createMap(int n) {
		HashMap<Content,Content> m = new HashMap<Content,Content>();
		while (n > 0) {
			Content key = new Content(Random.random());
			Content val = new Content(Random.random());
			m.put(key, val);
			n--;
		}
		return m;
	}
}

final class Content {
	int val;

	public Content(int v) {
		this.val = v;
	}

	public int hashCode() {
		return val^31;
	}

	public boolean equals(Object o) {
		if (o instanceof Content) {
			return this.val == ((Content) o).val;
		}
		return false;
	}
}
