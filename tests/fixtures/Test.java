
class Test {

  @Test
  public void shouldFindThis1() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest
  @ValueSource(ints = {1, 2, 3})
  public void shouldFindThis2(int i) {
    assertThat(i).isGreaterThan(0);
  }

  @Test
  public void shouldFindThis3() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest
  @MethodSource("provideStringsForIsBlank")
  public void shouldFindThis4() {
    assertThat(1).isEqualTo(1);
  }

  private void assertThat(int i) {
    // do nothing
  }
}

